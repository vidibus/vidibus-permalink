module Vidibus
  module Permalink
    module Mongoid
      extend ActiveSupport::Concern

      class PermalinkConfigurationError < StandardError; end

      included do
        field :permalink, type: String
        field :static_permalink, type: String

        index permalink: 1
        index static_permalink: 1

        attr_accessor :skip_permalink

        before_validation :set_permalink, unless: :skip_permalink
        validates :permalink, presence: true, unless: :skip_permalink

        after_save :store_permalink_object, unless: :skip_permalink
        after_destroy :destroy_permalink_objects
      end

      module ClassMethods

        # Sets permalink attributes.
        # Usage:
        #   permalink :some, :fields, :scope => {:realm => "rugby"}
        def permalink(*args)
          options = args.extract_options!
          class_eval <<-EOS
            def self.permalink_attributes
              #{args.inspect}
            end

            def self.permalink_options
              #{options.inspect}
            end
          EOS
        end
      end

      # Returns the defined permalink repository object.
      def permalink_repository
        @permalink_repository ||= begin
          self.class.permalink_options[:repository] == false ? nil : ::Permalink
        end
      end

      # Returns the current permalink object.
      def permalink_object
        @permalink_object || if permalink_repository
          permalink_repository.for_linkable(self).where(_current: true).first
        end
      end

      # Returns all permalink objects ordered by time of update.
      def permalink_objects
        if permalink_repository
          permalink_repository.for_linkable(self).asc(:updated_at)
        end
      end

      # Returns permalink scope.
      def permalink_scope
        @permalink_scope ||= get_scope
      end

      private

      # Returns a existing or new permalink object with wanted value.
      # The permalink scope is also applied
      def permalink_object_by_value(value)
        item = permalink_repository
          .for_linkable(self)
          .for_value(value)
          .for_scope(permalink_scope)
          .first
        item ||= permalink_repository.new({
          value: value,
          scope: permalink_scope,
          linkable: self
        })
      end

      def get_scope
        scope = self.class.permalink_options[:scope]
        return unless scope
        {}.tap do |hash|
          scope.each do |key, value|
            if value.kind_of?(String)
              hash[key] = value
            elsif value.kind_of?(Symbol) && respond_to?(value)
              hash[key] = send(value)
            else
              raise PermalinkConfigurationError.new(
                %Q{No scope value for key "#{key}" found.}
              )
            end
          end
        end
      end

      # Initializes a new permalink object and sets permalink attribute.
      def set_permalink
        begin
          attribute_names = self.class.permalink_attributes
        rescue NoMethodError
          raise PermalinkConfigurationError.new("#{self.class}.permalink_attributes have not been assigned! Use #{self.class}.permalink(:my_field) to set it up.")
        end

        changed = false
        values = []
        for a in attribute_names
          changed = send("#{a}_changed?") unless changed == true
          values << send(a)
        end
        return unless permalink.blank? or changed
        value = values.join(" ")
        if permalink_repository
          @permalink_object = permalink_object_by_value(value)
          @permalink_object.sanitize_value!
          @permalink_object.current!
          self.permalink = @permalink_object.value
        else
          self.permalink = ::Permalink.sanitize(value)
        end

        if new_record?
          self.static_permalink = self.permalink
        else
          self.static_permalink ||= self.permalink
        end
      end

      # Stores current new permalink object or updates an existing one that matches.
      def store_permalink_object
        return unless @permalink_object
        @permalink_object.updated_at = Time.now
        @permalink_object.save!
      end

      def destroy_permalink_objects
        if permalink_repository
          permalink_repository.delete_all(conditions: {linkable_id: id})
        end
      end
    end
  end
end
