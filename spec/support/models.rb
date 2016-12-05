class Asset
  include Mongoid::Document
  field :label
end

class Category
  include Mongoid::Document
  field :label
end
