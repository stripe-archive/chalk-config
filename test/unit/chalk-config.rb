require File.expand_path('../_lib', __FILE__)
require 'chalk-config'

class Critic::Functional::GeneralTest < Critic::Functional::Test
  before do
    fresh_chalk_config
  end

  describe '.assert_environment' do
    it 'raises if the environment is not in the array' do
      Chalk::Config.environment = 'hello'
      assert_raises(Chalk::Config::DisallowedEnvironment) do
        Chalk::Config.assert_environment(%w{foo bar})
      end
    end

    it 'raises if the environment is not the string' do
      Chalk::Config.environment = 'hello'
      assert_raises(Chalk::Config::DisallowedEnvironment) do
        Chalk::Config.assert_environment('foo')
      end
    end

    it 'does not raise if the environment is in the array' do
      Chalk::Config.environment = 'hello'
      Chalk::Config.assert_environment(%w{hello there})
    end

    it 'does not raise if the environment is the string' do
      Chalk::Config.environment = 'hello'
      Chalk::Config.assert_environment('hello')
    end
  end

  describe '.assert_not_environment' do
    it 'does not raise if the environment is not in the array' do
      Chalk::Config.environment = 'hello'
      Chalk::Config.assert_not_environment(%w{foo bar})
    end

    it 'does not raise if the environment is not the string' do
      Chalk::Config.environment = 'hello'
      Chalk::Config.assert_not_environment('foo')
    end

    it 'raises if the environment is in the array' do
      Chalk::Config.environment = 'hello'
      assert_raises(Chalk::Config::DisallowedEnvironment) do
        Chalk::Config.assert_not_environment(%w{hello there})
      end
    end

    it 'raises if the environment is the string' do
      Chalk::Config.environment = 'hello'
      assert_raises(Chalk::Config::DisallowedEnvironment) do
        Chalk::Config.assert_not_environment('hello')
      end
    end
  end
end
