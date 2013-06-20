require 'yaml'
require 'chalk-tools'
require 'chalk-config/version'

require 'configatron/core'
raise "Someone already loaded 'configatron'. You should always load 'configatron/core' instead." if defined?(configatron)
def configatron
  Configatron.instance
end
configatron # Calls reset! on initial instantiation, so need dummy call
Configatron.strict = true
Configatron.disable_monkey_patching = true

module Chalk::Config
  CONFIG_SCHEMA_FILE = 'config_schema.yaml'
  DEFAULT_CONFIG_FILE = 'config.yaml'
  DEFAULT_SITE_FILE = 'site.yaml'

  DEFAULT_ENV_FILE = 'env.yaml'
  ENV_SETTINGS = {
    # Defaults
    'environment' => nil, # what server class this is on
    'personality' => 'development', # production or development
    'deployed' => false, # server, or on a local machine
    'testing' => false # in the tests
  }

  @@initialized = false

  def self.production?
    configatron.env.personality == 'production'
  end

  def self.development?
    configatron.env.personality == 'development'
  end

  # Run this at load time. Discovers the environment, loads config
  # files, and then puts Configatron into strict mode so it will
  # raise on invalid keys.
  def self.init
    Configatron.strict = false

    begin
      init_schema
      init_from_config_files
    ensure
      Configatron.strict = true
    end

    @@initialized = true
  end

  def self.initialized?
    @@initialized
  end

  private

  def self.init_from_config_files
    config = configatron._meta.schema.config
    config_file = config.retrieve(:file, DEFAULT_CONFIG_FILE)
    nested_config_files = config.nested.to_hash

    site = configatron._meta.schema.site
    site_file = site.retrieve(:file, DEFAULT_SITE_FILE)
    nested_site_files = site.nested.to_hash

    files_to_load =
      [[nil, config_file]] +
      nested_config_files.to_a +
      [[nil, site_file]] +
      nested_site_files.to_a

    files_to_load.each do |key, file|
      subconfigatron = key ? configatron.send(key) : configatron
      locate_and_load(file, subconfigatron)
    end
  end

  # Load the schema, which is used to tell Config how to discover
  # its environment, and what config files to load. You shouldn't
  # have to care, but the schema is stored at
  # configatron._meta.schema.
  #
  # You can access environment values at configatron.env.<key>.
  def self.init_schema
    locate_and_load(CONFIG_SCHEMA_FILE, configatron._meta.schema) do
      load_env
    end
  end

  def self.load_env
    env_file = configatron._meta.schema.files.retrieve(:env_file, DEFAULT_ENV_FILE)

    if File.exists?(env_file)
      begin
        loaded = load_and_check(env_file)
      rescue StandardError => e
        raise "Could not load #{environment_spec_file}: #{e} (#{e.class})"
      end
      set_env_config(env_file, loaded)
    else
      set_env_defaults
    end

    set_env_from_environment_variables
  end

  def self.set_env_config(env_file, loaded)
    ENV_SETTINGS.keys.each do |key|
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

  def self.set_env_from_environment_variables
    configatron._meta.schema.env.to_hash.each do |key, variable|
      key = key.to_s
      raise "Invalid env key #{key.inspect} in #{configatron._meta.schema.env.inspect}" unless ENV_SETTINGS.include?(key)
      configatron.env[key] = ENV[variable] if ENV.include?(variable)
    end
  end

  def self.locate_and_load(files, subconfigatron=nil, &blk)
    file = locate(files)
    load_config(file, subconfigatron, &blk) if file
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
