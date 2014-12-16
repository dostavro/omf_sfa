require 'omf-sfa/models/resource'

module OMF::SFA::Model
  class Account < Resource
    one_to_many :resources
    many_to_many :users

    @@def_duration = 100 * 86400 # 100 days

    def active?
      return false unless self.closed_at.nil?

      valid_until = self.valid_until
      unless valid_until.kind_of? Time
        valid_until = Time.parse(valid_until) # seem to not be returned as Time
      end
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
    end

    # Open account
    def open
      self.closed_at = nil
    end

    def before_save
      self.created_at ||= Time.now
      self.valid_until ||= Time.now + @@def_duration
      super
    end
  end # Class
end # Module
