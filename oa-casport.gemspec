# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'oa-casport/version'

Gem::Specification.new do |gem|
  gem.name          = "oa-casport"
  gem.version       = OmniAuth::Casport::VERSION
  gem.authors       = ["Steven Haddox"]
  gem.email         = ["steven.haddox@gmail.com"]
  gem.description   = %q{ Simple gem to enable rack powered Ruby apps to authenticate internally via casport with ease}
  gem.summary       = %q{OmniAuth gem for internal casport server}
  gem.homepage      = "https://github.com/stevenhaddox/oa-casport"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency 'omniauth', '~> 1.0'

  gem.add_dependency 'json'
  gem.add_dependency 'multi_xml'

  gem.add_development_dependency 'rack-test'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec', '~> 2.6'
  gem.add_development_dependency 'sinatra'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'webmock', '~> 1.7'
  gem.add_development_dependency 'yard'
end
