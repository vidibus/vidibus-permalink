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
  name = 'vidibus-permalink_test'
  host = 'localhost'
  config.master = Mongo::Connection.new.db(name)
  config.logger = nil
end

RSpec.configure do |config|
  config.mock_with :rr
  config.before(:each) do
    Mongoid.master.collections.select {|c| c.name !~ /system/}.each(&:drop)
  end
end

I18n.load_path += Dir[File.join('config', 'locales', '**', '*.{rb,yml}')]

# Helper for stubbing time. Define String to be set as Time.now.
# Usage:
#   stub_time('01.01.2010 14:00')
#   stub_time(2.days.ago)
#
def stub_time!(string = nil)
  string ||= Time.now.to_s(:db)
  now = Time.parse(string.to_s)
  stub(Time).now {now}
  now
end
