require 'omf-sfa/models/resource'

module OMF::SFA::Model
  class Account < Resource
    one_to_many :resources
    many_to_many :users

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
      save
    end
  end
end
