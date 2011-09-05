require "vidibus-uuid"

class Asset
  include Mongoid::Document
  include Vidibus::Uuid::Mongoid
  field :label
end

class Category
  include Mongoid::Document
  include Vidibus::Uuid::Mongoid
  field :label
end
