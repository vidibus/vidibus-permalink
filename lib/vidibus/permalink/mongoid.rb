module Vidibus
  module Permalink
    module Mongoid
      extend ActiveSupport::Concern

      class PermalinkConfigurationError < StandardError; end

      included do
        field :permalink, :type => String
        index :permalink
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
        @permalink_repository ||= (self.class.permalink_options[:repository] == false) ? nil : ::Permalink
      end

      # Returns the current permalink object.
      def permalink_object
        @permalink_object || permalink_repository.for_linkable(self).where(:_current => true).first if permalink_repository
      end

      # Returns all permalink objects ordered by time of update.
      def permalink_objects
        permalink_repository.for_linkable(self).asc(:updated_at) if permalink_repository
      end

      protected

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
          @permalink_object = permalink_repository.for_linkable(self).for_value(value).first || permalink_repository.new(:value => value, :linkable => self)
          self.permalink = @permalink_object.value
        else
          self.permalink = ::Permalink.sanitize(value)
        end
      end

      # Stores current new permalink object or updates an existing one that matches.
      def store_permalink_object
        return unless @permalink_object
        @permalink_object.updated_at = Time.now
        @permalink_object.save!
      end

      def destroy_permalink_objects
        permalink_repository.delete_all(:conditions => {:linkable_uuid => uuid}) if permalink_repository
      end
    end
  end
end