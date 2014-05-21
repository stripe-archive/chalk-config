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

# The main class powering Chalk's configuration.
#
# This is written using a wrapped Singleton, which makes testing
# possible (just stub `Chalk::Config.instance` to return a fresh
# instance) and helps hide implementation.
class Chalk::Config
  include Singleton

  # Thrown if an environment is missing from a config file.
  class MissingEnvironment < StandardError; end

  # Sets the current environment. All configuration is then reapplied
  # in the order it was {.register}ed. This means you don't have to
  # worry about setting your environment prior to registering config
  # files.
  #
  # @return [String] The current environment.
  def self.environment=(name)
    instance.send(:environment=, name)
  end

  # @return [String] The current environment (default: `'default'`)
  def self.environment
    instance.send(:environment)
  end

  # Specify the list of environments every configuration file must
  # include.
  #
  # It's generally recommended to set this in a wrapper library, and
  # use that wrapper library in all your projects. This way you can be
  # defensive, and have certainty no config file slips through without
  # the requisite environment keys.
  #
  # @param environments [Enumerable<String>] The list of required environments.
  def self.required_environments=(environments)
    instance.send(:required_environments=, environments)
  end

  # Access the environments registered by {.required_environments=}.
  #
  # @return [Enumerable] The registered environments list (by default, nil)
  def self.required_environments
    instance.send(:required_environments)
  end

  # Register a given YAML file to be included in the global
  # configuration.
  #
  # The config will be loaded once (cached in memory) and be
  # immediately deep-merged onto configatron. If you later run
  # {.environment=}, then all registered configs will be reapplied in
  # the order they were loaded.
  #
  # So for example, running
  # `Chalk::Config.register('/path/to/config.yaml')` for a file with
  # contents:
  #
  # ```yaml
  # env1:
  #   key1: value1
  #   key2: value2
  # ```
  #
  # would yield `configatron.env1.key1 == value1`,
  # `configatron.env1.key2 == value2`. Later registering a file with
  # contents:
  #
  # ```yaml
  # env1:
  #   key1: value3
  # ```
  #
  # would yield `configatron.env1.key1 == value3`,
  # `configatron.env1.key2 == value2`.
  #
  # @param filepath [String] Absolute path to the config file
  # @option filepath [Boolean] :optional If true, it's fine for the file to be missing, in which case this registration is discarded.
  # @option filepath [Boolean] :raw If true, the file doesn't have environment keys and should be splatted onto configatron directly. Otherwise, grab just the config under the appropriate environment key.
  # @option filepath [String] :nested What key to namespace all of this configuration under. (So `nested: 'foo'` would result in configuration available under `configatron.foo.*`.)
  def self.register(filepath, options={})
    unless filepath.start_with?('/')
      raise ArgumentError.new("Register only accepts absolute paths, not #{filepath.inspect}. (This ensures that config is always correctly loaded rather than depending on your current directory. To avoid this error in the future, you may want to use a wrapper that expands paths based on a base directory.)")
    end
    instance.send(:register, filepath, options)
  end

  # Register a given raw hash to be included in the global
  # configuration.
  #
  # This allows you to specify arbitrary configuration at
  # runtime. It's generally not recommended that you use this method
  # unless your configuration really can't be encoded in config
  # files. A common example is configuration from environment
  # variables (which might be something like the name of your
  # service).
  #
  # Like {.register}, if you later run {.environment=}, this
  # configuration will be reapplied in the order it was registered.
  #
  # @param config [Hash] The raw configuration to be deep-merged into configatron.
  def self.register_raw(config)
    instance.send(:register_raw, config)
  end

  private

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

  def register(filepath, options)
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

    register_parsed(config, filepath, options)
  end

  def register_raw(config)
    register_parsed(config, nil, {})
  end

  private

  # Register some raw config
  def register_parsed(config, filepath, options)
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
    begin
      loaded = YAML.load_file(filepath)
    rescue StandardError => e
      e.message << " (while loading #{filepath})"
      raise
    end
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
