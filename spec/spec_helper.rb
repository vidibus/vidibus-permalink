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

Mongoid.configure do |config|
  config.connect_to('vidibus-permalink_test')
end

RSpec.configure do |config|
  config.mock_with :rr
  config.before(:each) do
    Mongoid::Sessions.default.collections.select do |c|
      c.name !~ /system/
    end.each(&:drop)
  end
end

I18n.load_path += Dir[File.join('config', 'locales', '**', '*.{rb,yml}')]
