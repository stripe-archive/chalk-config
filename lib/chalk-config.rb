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
  @config_cache = []
  # This makes it so that we're unable to add the same file with different
  # nesting for now, which may be the desired behavior (I'm not absolutely
  # certain this is what we want, but it does make the diffing easier).
  @applied_configs = Set.new

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
    if @applied_configs.include?(filepath)
      # Ick, we're raising strings...
      raise "You've already registered #{filepath}."
    end

    config = load!(filepath, options)

    if config
      # Push to config_cache to preserve order of registration.
      @config_cache << generate_cached_config(filepath, config, options)
      update_config
    end
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

  def self.load!(filepath, options)
    begin
      loaded = YAML.load_file(filepath)
    rescue Errno::ENOENT
      return nil if options[:optional]
      raise
    end
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
    @applied_configs = Set.new
    allow_configatron_changes do
      configatron.reset!
    end
  end

  def self.update_config
    allow_configatron_changes do
      @config_cache.each do |contents|
        next if @applied_configs.include?(contents[:file])

        mixin_config(contents[:config], contents[:overrides], contents[:options][:nested])
        @applied_configs.add(contents[:file])
      end
    end
    nil
  end
end
