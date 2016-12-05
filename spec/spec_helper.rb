require 'simplecov'
SimpleCov.start

$:.unshift File.expand_path('../../', __FILE__)
$:.unshift File.expand_path('../../lib', __FILE__)
$:.unshift File.expand_path('../../app', __FILE__)

require 'rubygems'
require 'rspec'
require 'rr'
require 'vidibus-permalink'

Dir[File.expand_path('spec/support/**/*.rb')].each { |f| require f }
require 'models/permalink'

Mongoid::Config.connect_to('vidibus-permalink_test')
Mongo::Logger.logger.level = ::Logger::INFO

RSpec.configure do |config|
  config.mock_with :rr
  config.before(:each) do
    Mongoid::Config.purge!
  end
end

I18n.load_path += Dir[File.join('config', 'locales', '**', '*.{rb,yml}')]
