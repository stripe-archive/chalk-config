require File.expand_path('../_lib', __FILE__)
require 'chalk-config'

class Critic::Functional::GeneralTest < Critic::Functional::Test
  before do
    # Set up a fresh Chalk::Config and Configatron instance
    configatron = Configatron.send(:new)
    Configatron.stubs(instance: configatron)
    # This is needed because the new configatron instance internally
    # calls reset.
    Configatron.strict = true

    fresh_chalk_config

    Chalk::Config.environment = 'testing'
    Chalk::Config.register(File.expand_path('../general/config.yaml', __FILE__))
  end

  it 'loads config correctly' do
    assert_equal('value1', configatron.config1)
    assert_equal('value3', configatron.config2)
  end

  it 'allows switching environments' do
    Chalk::Config.environment = 'default'
    assert_equal('value1', configatron.config1)
    assert_equal('value2', configatron.config2)
  end

  describe 'register_raw' do
    it 'merges in registered config' do
      Chalk::Config.register_raw(foo: 'bar', config1: 'hi')
      assert_equal('bar', configatron.foo)
      assert_equal('hi', configatron.config1)
    end

    it 'environment validation continues to succeed' do
      Chalk::Config.register_raw(foo: 'bar')
      Chalk::Config.required_environments = ['default']
    end
  end

  describe 'raw files' do
    it 'merges the file contents directly' do
      Chalk::Config.register(File.expand_path('../general/raw.yaml', __FILE__),
        raw: true)
      assert_equal('there', configatron.hi)
      assert_equal('bat', configatron.baz)
      assert_equal('no_environment', configatron.config1)
    end

    it 'does not try to validate presence of environments' do
      Chalk::Config.required_environments = ['default']
      Chalk::Config.register(File.expand_path('../general/raw.yaml', __FILE__),
        raw: true)
    end
  end

  describe 'missing nested files' do
    it 'does not create the relevant config key' do
      Chalk::Config.register(File.expand_path('../general/nonexistent.yaml', __FILE__),
        optional: true,
        nested: 'nonexistent')
      assert_raises(KeyError) do
        configatron.nonexistent
      end
    end

    it 'environment validation continues to succeed' do
      Chalk::Config.register(File.expand_path('../general/nonexistent.yaml', __FILE__),
        optional: true,
        nested: 'nonexistent')
      Chalk::Config.required_environments = ['default']
    end
  end

  describe 'nested config files' do
    it 'nests' do
      Chalk::Config.register(File.expand_path('../general/raw.yaml', __FILE__),
        nested: 'nested',
        raw: true)
      assert_equal('there', configatron.nested.hi)
    end

    it 'deep-nests' do
      Chalk::Config.register(File.expand_path('../general/raw.yaml', __FILE__),
        nested: 'nested.deeply',
        raw: true)
      assert_equal('there', configatron.nested.deeply.hi)
    end
  end

  describe 'required_environments' do
    it 'raises if an existing config is missing an environment' do
      assert_raises(Chalk::Config::MissingEnvironment) do
        Chalk::Config.required_environments = ['missing']
      end
    end

    it 'raises if a new config is missing an environment' do
      Chalk::Config.required_environments = ['testing']
      assert_raises(Chalk::Config::MissingEnvironment) do
        Chalk::Config.register(File.expand_path('../general/missing.yaml', __FILE__))
      end
    end
  end
end
