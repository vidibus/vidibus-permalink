module Vidibus
  module Permalink
    module Mongoid
      extend ActiveSupport::Concern

      class PermalinkConfigurationError < StandardError; end

      included do
        field :permalink
        before_validation :set_permalink
        validates :permalink, :presence => true
        after_save :store_permalink_object
        after_destroy :destroy_permalink_objects
      end

      module ClassMethods

        # Sets permalink attributes.
        # Usage:
        #   permalink :some, :fields
        def permalink(*args)
          class_eval <<-EOS
            def permalink_attributes
              #{args.inspect}
            end
          EOS
        end
      end

      # Returns the current permalink object.
      def permalink_object
        @permalink_object || ::Permalink.for_linkable(self).where(:_current => true).first
      end

      # Returns all permalink objects ordered by time of update.
      def permalink_objects
        ::Permalink.for_linkable(self).asc(:updated_at)
      end

      protected

      # Initializes a new permalink object and sets permalink attribute.
      def set_permalink
        if attributes = try!(:permalink_attributes)
          changed = false
          values = []
          for a in attributes
            changed = send("#{a}_changed?") unless changed == true
            values << send(a)
          end
          return unless permalink.blank? or changed
          value = values.join(" ")
          @permalink_object = ::Permalink.for_linkable(self).for_value(value).first
          @permalink_object ||= ::Permalink.new(:value => value, :linkable => self)
          self.permalink = @permalink_object.value
        else
          raise PermalinkConfigurationError.new("Permalink attributes have not been assigned!")
        end
      end

      # Stores current new permalink object or updates an existing one that matches.
      def store_permalink_object
        @permalink_object.save! if @permalink_object
      end

      def destroy_permalink_objects
        ::Permalink.delete_all(:conditions => {:linkable_uuid => uuid})
      end
    end
  end
end