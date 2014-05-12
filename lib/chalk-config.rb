require 'set'
require 'yaml'
require 'chalk-config/version'

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

class Chalk::Config
  include Singleton

  class MissingEnvironment < StandardError; end

  ## Class methods here serve as the public-interface

  def self.environment=(name)
    instance.environment = name
  end

  def self.environment
    instance.environment
  end

  def self.required_environments=(environments)
    instance.required_environments = environments
  end

  def self.required_environments
    instance.required_environments
  end

  # Loads, interprets, and caches the given YAML file, afterwards reconfiguring.
  def self.register(filepath, options={})
    instance.register(filepath, options)
  end

  def self.runtime_config=(config)
    instance.runtime_config = config
  end

  def initialize
    # List of registered configs, in the form:
    #
    # file => {config: ..., options: ...}
    @registrations = []
    @registered_files = Set.new
    @environment = 'default'
  end

  ## The actual instance implementations

  # Possibly reconfigure if the environment changes.
  def environment=(name)
    @environment = name
    reapply_config
  end

  def environment
    @environment
  end

  def required_environments=(environments)
    @required_environments = environments
    @registrations.each do |registration|
      # Validate all existing config
      validate_config(registration)
    end
  end

  def required_environments
    @required_environments
  end

  # Set configatron.runtime_config key
  def runtime_config=(config)
    register_raw(config, nil, nested: 'runtime_config')
  end

  def register(filepath, options)
    # Expand relative paths. This is for use in library code.
    #
    # TODO: should we put in some controls to ensure that library
    # config always gets applied before application config?
    if relative_to = options[:relative_to]
      filepath = File.expand_path(filepath, File.join(relative_to, '..'))
    end

    if @registered_files.include?(filepath)
      raise "You've already registered #{filepath}."
    end
    @registered_files << filepath

    begin
      config = load!(filepath)
    rescue Errno::ENOENT
      return if options[:optional]
      raise
    end

    register_raw(config, filepath, options)
  end

  private

  # Register some raw config
  def register_raw(config, filepath, options)
    allow_configatron_changes do
      directive = {
        config: config,
        filepath: filepath,
        options: options,
      }

      validate_config(directive)
      @registrations << directive

      allow_configatron_changes do
        mixin_config(directive)
      end
    end
  end

  def allow_configatron_changes(&blk)
    Configatron.strict = false

    begin
      blk.call
    ensure
      Configatron.strict = true
    end
  end

  def load!(filepath)
    loaded = YAML.load_file(filepath)
    unless loaded.is_a?(Hash)
      raise "YAML.load(#{filepath.inspect}) parses into a #{loaded.class}, not a Hash"
    end
    loaded
  end

  # Take a hash and mix in the environment-appropriate key to an
  # existing configatron object.
  def mixin_config(directive)
    raw = directive[:options][:raw]

    config = directive[:config]
    filepath = directive[:filepath]

    if !raw && filepath && config && !config.include?(environment)
      # Directive is derived from a file (i.e. not runtime_config)
      # with environments and that file existed, but is missing the
      # environment.
      raise MissingEnvironment.new("Current environment #{environment.inspect} not defined in config file #{directive[:filepath].inspect}. (HINT: you should have a YAML key of #{environment.inspect}. You may want to inherit a default via YAML's `<<` operator.)")
    end

    if raw
      choice = config
    elsif filepath && config
      # Derived from file, and file present
      choice = config.fetch(environment)
    elsif filepath
      # Derived from file, but file missing
      choice = {}
    else
      # Manually specified runtime_config
      choice = config
    end

    if nested = directive[:options][:nested]
      subconfigatron = configatron[nested]
    else
      subconfigatron = configatron
    end

    subconfigatron.configure_from_hash(choice)
  end

  def validate_config(directive)
    (@required_environments || []).each do |environment|
      raw = directive[:options][:raw]

      config = directive[:config]
      filepath = directive[:filepath]

      next if raw

      if filepath && config && !config.include?(environment)
        raise MissingEnvironment.new("Required environment #{environment.inspect} not defined in config file #{directive[:filepath].inspect}. (HINT: you should have a YAML key of #{environment.inspect}. You may want to inherit a default via YAML's `<<` operator.)")
      end
    end
  end

  def reapply_config
    allow_configatron_changes do
      configatron.reset!
      @registrations.each do |registration|
        mixin_config(registration)
      end
    end
  end
end
