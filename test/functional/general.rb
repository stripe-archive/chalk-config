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

    config = Chalk::Config.send(:new)
    Chalk::Config.stubs(instance: config)

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
