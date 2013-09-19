# encoding: utf-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'vidibus/permalink/version'

Gem::Specification.new do |s|
  s.name = 'vidibus-permalink'
  s.version = Vidibus::Permalink::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = 'Andre Pankratz'
  s.email = 'andre@vidibus.com'
  s.homepage = 'https://github.com/vidibus/vidibus-permalink'
  s.summary = 'Permalink handling'
  s.description = 'Allows changeable permalinks (good for SEO).'
  s.license = 'MIT'

  s.required_rubygems_version = '>= 1.3.6'

  s.add_dependency 'activesupport', '~> 3'
  s.add_dependency 'mongoid', '~> 2'
  s.add_dependency 'vidibus-core_extensions'
  s.add_dependency 'vidibus-uuid', '~> 0.4'
  s.add_dependency 'vidibus-words'

  s.add_development_dependency 'bundler', '>= 1.0.0'
  s.add_development_dependency 'rspec', '~> 2'
  s.add_development_dependency 'rr'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'simplecov'

  s.files = Dir.glob('{lib,app,config}/**/*') + %w[LICENSE README.md Rakefile]
  s.require_path = 'lib'
end
