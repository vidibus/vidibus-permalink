class Permalink
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :linkable, polymorphic: true

  field :value
  field :scope, type: Array
  field :_current, type: Boolean, default: true

  before_validation :sanitize_value!
  after_save :unset_other_current, if: :current?
  after_destroy :set_last_current, if: :current?

  validates :value, :linkable, presence: true

  index({value: 1}, {sparse: true})

  # Sanitizes and increments string, if necessary.
  def sanitize_value!
    return true unless value_changed? || new_record?
    string = sanitize(value)
    if string != value_was
      string = increment(string)
    end
    self.value = string
    true
  end

  def scope=(scope)
    if array = scope
      array = self.class.scope_list(scope)
      self.write_attribute(:scope, array)
    end
    array
  end

  # Returns true if this permalink is the current one
  # of the assigned linkable.
  def current?
    !!_current
  end

  # Returns the current permalink of the assigned linkable.
  def current
    @current ||= begin
      if current?
        self
      else
        Permalink.where({
          linkable_id: linkable.id,
          linkable_type: linkable.class.to_s,
          _current: true
        }).first
      end
    end
  end

  # Sets this permalink as the current one.
  # All other permalinks of this linkable will be updated after saving.
  def current!
    self._current = true
  end

  class << self
    # Scope method for finding Permalinks for given object.
    def for_linkable(object)
      where(linkable_id: object.id, linkable_type: object.class.to_s)
    end

    # Scope method for finding Permalinks for given value.
    # The value will be sanitized.
    def for_value(value, do_sanitize = true)
      if do_sanitize
        self.or([
          {value: /^#{sanitize(value)}(-\d+)?$/},
          {value: /^#{sanitize(value, true)}(-\d+)?$/}
        ])
      else
        where(value: /^#{value}(-\d+)?$/)
      end
    end

    def for_scope(scope)
      return all unless scope
      all_in(scope: scope_list(scope))
    end

    # Returns a dispatcher object for given path.
    def dispatch(path, options = {})
      Vidibus::Permalink::Dispatcher.new(path, options)
    end

    # Sanitizes string: Remove stopwords and format as permalink.
    # See Vidibus::CoreExtensions::String for details.
    def sanitize(string, keep_stopwords = false)
      return if string.blank?
      string = remove_stopwords(string) unless keep_stopwords
      string.permalink
    end

    def scope_list(scope)
      return [] unless scope
      return scope if scope.kind_of?(Array)
      scope.map { |key, value| "#{key}:#{value}" }
    end
  end

  protected

  # Removes stopwords and turns string into a permalink-formatted one.
  # However, if the stopwords-free value is blank or it already exists
  # in the database, the full value will be used.
  def sanitize(string)
    return if string.blank?
    clean = Permalink.remove_stopwords(string)
    unless clean.blank? or clean == string
      clean = clean.permalink
      sanitized = clean unless existing(clean).any?
    end
    sanitized || string.permalink
  end

  # Tries to remove stopwords from string.
  # If the resulting string is blank, the original one will be returned.
  # See Vidibus::Words for details.
  def self.remove_stopwords(string)
    words = Vidibus::Words.new(string)
    clean = words.keywords(10).join(" ")
    clean.blank? ? string : clean
  end

  # Appends next available number to string if it's already in use.
  def increment(string)
    _existing = existing(string)
    return string unless _existing.any?
    return string unless _existing.detect {|e| e.value == string}
    number = 1
    while true
      number += 1
      desired = "#{string}-#{number}"
      unless _existing.detect {|e| e.value == desired}
        return desired
      end
    end
  end

  # Finds existing permalinks with current value.
  def existing(string)
    @existing ||= {}
    @existing[string] ||= Permalink
      .for_scope(scope)
      .for_value(string, false)
      .excludes(:_id => id)
      .to_a
  end

  # Sets _current to false on all permalinks of the assigned linkable.
  def unset_other_current
    return unless linkable
    conditions = {
      linkable_id: linkable.id,
      linkable_type: linkable.class.to_s,
      _id: {'$ne' => id}
    }
    conditions[:scope] = Permalink.scope_list(scope) if scope.present?
    Permalink.where(conditions).each do |obj|
      obj.set(_current: false)
    end
  end

  # Sets the lastly updated permalink of the assigned linkable as current one.
  def set_last_current
    last = Permalink
      .where(linkable_id: linkable.id, linkable_type: linkable.class.to_s)
      .order_by(:updated_at.desc)
      .limit(1)
      .first
    if last
      last.update_attributes!(_current: true)
    end
  end
end
