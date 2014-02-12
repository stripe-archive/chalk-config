require 'yaml'
require 'chalk-tools'
require 'chalk-config/version'
require 'chalk-framework-builder'

require 'configatron/core'
raise "Someone already loaded 'configatron'. You should always load 'configatron/core' instead." if defined?(configatron)
def configatron
  Configatron.instance
end
configatron # Calls reset! on initial instantiation, so need dummy call
Configatron.strict = true
Configatron.disable_monkey_patching = true
# Stop configatron from sadly spewing on configure_from_hash
if defined?(Configatron::Store::SYCK_CONSTANT)
  Configatron::Store.send(:remove_const, 'SYCK_CONSTANT')
end

# When a file is registered, we load the file and cache that.
# Separately maintain the merged version.
# When environment changes, we use the cached file.


module Chalk::Config
  include Chalk::FrameworkBuilder::Configurable

  # Array (to preserve registration order) of
  # { file: ..., config: ..., overrides: ..., options: ... }
  @cached_configs = []
  # This makes it so that we're unable to add the same file with different
  # nesting for now, which may be the desired behavior (I'm not absolutely
  # certain this is what we want, but it does make the diffing easier).
  @updated_configs = Set.new

  # Possibly reconfigure if the environment changes.
  def self.environment=(name)
    @environment = name
    clear_config
    update_config
  end

  def self.environment
    @environment
  end

  # Loads, interprets, and caches the given YAML file, afterwards reconfiguring.
  def self.register(filepath, options={})
    if @updated_configs.include?(filepath)
      # Ick, we're raising strings...
      raise "You've already registered #{filepath}."
    end

    config = load!(filepath)

    # Push to cached_configs to preserve order of registration.
    @cached_configs.push(generate_cached_config(filepath, config, options))

    update_config
  end


  private

  def self.allow_configatron_changes(&blk)
    Configatron.strict = false

    begin
      blk.call
    ensure
      Configatron.strict = true
    end
  end

  def self.generate_cached_config(file, config, options)
    return {
      overrides: config.delete('overrides') || {},
      config: config,
      options: options,
      file: file
    }
  end

  def self.load!(filepath)
    loaded = YAML.load_file(filepath)
    raise "Not a valid YAML file: #{filepath}" unless loaded.is_a?(Hash)
    loaded
  end

  # Take a hash and mix it in to an existing configatron
  # object. Also mix in any environment-specific overrides.
  def self.mixin_config(config, overrides, nested)
    if nested
      subconfigatron = configatron[nested]
    else
      subconfigatron = configatron
    end

    subconfigatron.configure_from_hash(config)

    if override = overrides[environment]
      subconfigatron.configure_from_hash(overrides)
    end
  end

  def self.clear_config
    @updated_configs = Set.new
    allow_configatron_changes do
      configatron.reset!
    end
  end

  def self.update_config
    allow_configatron_changes do
      @cached_configs.each do |contents|
        next if @updated_configs.include?(contents[:file])

        mixin_config(contents[:config], contents[:overrides], contents[:options][:nested])
        @updated_configs.add(contents[:file])
      end
    end
    nil
  end
end

__END__
  CONFIG_SCHEMA_FILE = 'config_schema.yaml'
  DEFAULT_CONFIG_FILE = 'config.yaml'
  DEFAULT_SITE_FILE = 'site.yaml'

  DEFAULT_ENV_FILE = 'env.yaml'
  ENV_SETTINGS = {
    # Defaults
    'name' => 'local', # An alias for the current environment.
    'environment' => nil, # what server class this is on
    'personality' => 'development', # production or development
    'deployed' => false, # server, or on a local machine
    'testing' => false # in the tests
  }

  def self.production?
    configatron.env.personality == 'production'
  end

  def self.development?
    configatron.env.personality == 'development'
  end

  def self.set_env_config(env_file, loaded)
    ENV_SETTINGS.keys.each do |key|
      # Currently we require all env settings keys to be present; this doesn't
      # need to be the case in the near future.
      unless loaded.include?(key)
        raise "Missing key #{key} from settings loaded from #{env_file}"
      end
      configatron.env[key] = loaded[key]
    end
  end

  def self.set_env_defaults
    ENV_SETTINGS.each do |key, default|
      configatron.env[key] = default
    end
  end


  def self.load_config(file, subconfigatron=nil, &blk)
    begin
      loaded = load_and_check(file)
    rescue StandardError => e
      raise "Could not load #{file}: #{e} (#{e.class})"
    else
      mixin_config(loaded, subconfigatron, &blk)
    end
  end

  def self.load_and_check(file)
    loaded = YAML.load_file(file)
    raise "Not a valid YAML file: #{file}" unless loaded.is_a?(Hash)
    loaded
  end

  # Take a hash and mix it in to an existing configatron
  # object. Also mix in any environment-specific overrides.
  def self.mixin_config(hash, subconfigatron=nil, &blk)
    subconfigatron ||= configatron

    subconfigatron.configure_from_hash(hash)
    # This is needed to solve a bootstrapping problem: we need to
    # detect the environment before performing any overrides, so we
    # need to be able to inject our own code in the middle here.
    blk.call if blk
    overrides = hash.fetch('overrides', {})
    override_hashes = ENV_SETTINGS.keys.each do |key|
      next unless configatron.env.exists?(key)
      # Configatron can only have string/symbol keys
      setting = configatron.env.retrieve(key)
      override = overrides.fetch(key, {}).fetch(setting.to_s, {})
      subconfigatron.configure_from_hash(override)
    end
  end

  def self.locate(files)
    files = [files] unless files.kind_of?(Array)
    expanded = files.map do |path|
      Chalk::Tools::PathUtils.path(path)
    end

    file = expanded.detect {|file| File.exists?(file)}
    unless configatron._meta.schema.files_optional || file
      raise "You need to create one of the config files: #{files.inspect}"
    end

    file
  end
end
