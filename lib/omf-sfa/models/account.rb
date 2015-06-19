require 'omf-sfa/models/resource'

module OMF::SFA::Model
  class Account < Resource
    one_to_many :resources
    many_to_many :users

    plugin :nested_attributes
    nested_attributes :users, :resources

    @@def_duration = 1000 * 86400 # 1000 days

    def active?
      return false unless self.closed_at.nil?

      if Time.now > valid_until
        self.close()
        return false
      end
      true
    end

    def closed?
      ! active?
    end

    # Close account
    def close
      self.closed_at = Time.now
      save
    end

    # Open account
    def open
      self.closed_at = nil
      save
    end

    def before_save
      self.created_at ||= Time.now
      self.valid_until ||= Time.now + @@def_duration
      super
    end

    def self.include_nested_attributes_to_json
      sup = super
      [:users].concat(sup)
    end
  end # Class
end # Module
