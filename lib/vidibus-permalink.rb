require "active_support"
require "mongoid"
require "vidibus-core_extensions"
require "vidibus-words"

require "vidibus/permalink"

if defined?(Rails)
  module Vidibus::Permalink
    class Engine < ::Rails::Engine; end
  end
end
