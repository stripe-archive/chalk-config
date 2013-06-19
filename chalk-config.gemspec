# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chalk-config/version'

Gem::Specification.new do |gem|
  gem.name          = 'chalk-config'
  gem.version       = Chalk::Config::VERSION
  gem.authors       = ['Stripe']
  gem.email         = ['oss@stripe.com']
  gem.description   = %q{Layer over configatron with conventions for environment-based and site-specific config}
  gem.summary       = %q{chalk-configatron uses a config_schema.yaml file to figure out how to configure your app}
  gem.homepage      = 'https://github.com/stripe/chalk-config'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']
  gem.add_dependency 'configatron', '~> 4.4'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'minitest'
  gem.add_development_dependency 'mocha'
  gem.add_development_dependency 'chalk-rake'
end
