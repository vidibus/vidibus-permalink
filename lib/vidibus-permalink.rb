require "rails"
require "mongoid"
require "vidibus-core_extensions"
require "vidibus-uuid"
require "vidibus-words"
    
$:.unshift(File.join(File.dirname(__FILE__), "vidibus"))
require "permalink"

if defined?(Rails)
  module Vidibus::Permalink
    class Engine < ::Rails::Engine; end
  end
end
