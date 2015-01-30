# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'state_machines/integrations/active_model/observers/version'

Gem::Specification.new do |spec|
  spec.name          = 'state_machines-activemodel-observers'
  spec.version       = StateMachines::Integrations::ActiveModel::Observers::VERSION
  spec.authors       = ['Abdelkader Boudih', 'Aaron Pfeifer']
  spec.email         = ['terminale@gmail.com']
  spec.summary       = %q(ActiveModel Observers integration for State Machines)
  spec.description   = %q(Adds support for ActiveModel Observers)
  spec.homepage      = 'https://github.com/seuros/state_machines-activemodel-observers'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = ['lib']
  spec.required_ruby_version     = '>= 2.0.0'

  spec.add_dependency 'state_machines-activemodel'    , '>= 0.1.4'
  spec.add_dependency 'rails-observers'

  spec.add_development_dependency 'bundler', '>= 1.6'
  spec.add_development_dependency 'rake', '>= 10'
  spec.add_development_dependency 'appraisal', '>= 1'
  spec.add_development_dependency 'rspec' , '~>3.1.0'
end
