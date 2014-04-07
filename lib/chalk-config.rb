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

  # Hash (relies on registration order being preserved) of
  # file => {config: ..., overrides: ..., options: ..., tags: ...}
  @registrations = {}
  @tags = Set.new

  # Possibly reconfigure if the environment changes.
  def self.environment=(name)
    @environment = name
    reapply_config
  end

  def self.environment
    @environment
  end

  # Loads, interprets, and caches the given YAML file, afterwards reconfiguring.
  def self.register(filepath, options={})
    if @registrations.include?(filepath)
      raise "You've already registered #{filepath}."
    end

    begin
      config = load!(filepath)
    rescue Errno::ENOENT
      raise unless options[:optional]
      config = {}
    end

    overrides, tags = extract_overrides!(config)
    directive = {
      overrides: overrides,
      tags: tags,
      config: config,
      options: options,
    }

    @registrations[filepath] = directive
    apply_directive(directive)
  end

  def self.add_tag(tag)
    @tags << tag
    reapply_config
  end

  def self.tag?(tag)
    @tags.include?(tag)
  end

  private

  def self.extract_overrides!(config)
    overrides = config.fetch('__overrides', {})
    tags = overrides.fetch('__tags', {})
    # Make sure the user didn't specify a nonsensical override
    unless overrides.kind_of?(Hash)
      raise "Invalid overrides hash specified in #{filepath}: #{overrides.inspect}"
    end
    unless tags.kind_of?(Hash)
      raise "Invalid tags hash specified in #{filepath}: #{tags.inspect}"
    end
    config.delete('__overrides')
    overrides.delete('__tags')

    [overrides, tags]
  end

  def self.allow_configatron_changes(&blk)
    Configatron.strict = false

    begin
      blk.call
    ensure
      Configatron.strict = true
    end
  end

  def self.load!(filepath)
    loaded = YAML.load_file(filepath)
    unless loaded.is_a?(Hash)
      raise "YAML.load(#{filepath.inspect}) parses into a #{loaded.class}, not a Hash"
    end
    loaded
  end

  def self.apply_directive(directive)
    mixin_config(
      directive[:config], directive[:overrides], directive[:tags], directive[:options][:nested]
    )
  end

  # Take a hash and mix it in to an existing configatron
  # object. Also mix in any environment-specific overrides.
  def self.mixin_config(config, overrides, tags, nested)
    if nested
      subconfigatron = configatron[nested]
    else
      subconfigatron = configatron
    end

    subconfigatron.configure_from_hash(config)

    if override = overrides[environment]
      subconfigatron.configure_from_hash(override)
    end

    tags.each do |tag, override|
      if tag?(tag)
        subconfigatron.configure_from_hash(override)
      end
    end
  end

  def self.reapply_config
    allow_configatron_changes do
      configatron.reset!
      @registrations.each do |_, registration|
        apply_directive(registration)
      end
    end
  end
end
