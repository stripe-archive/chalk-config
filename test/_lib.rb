require 'rubygems'
require 'bundler/setup'

require 'minitest/autorun'
require 'minitest/spec'
require 'mocha/setup'

module Critic
  class Test < ::MiniTest::Spec
    def setup
      # Put any stubs here that you want to apply globally
    end

    def fresh_chalk_config
      config = Chalk::Config.send(:new)
      Chalk::Config.stubs(instance: config)
    end
  end
end
