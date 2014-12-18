require 'omf-sfa/models/resource'

module OMF::SFA::Model
  class User < Resource
    one_to_many :keys
    many_to_many :accounts

    def has_nil_account?(am_manager)
      self.accounts.include?(am_manager.get_scheduler.get_nil_account)
    end

    def self.include_nested_attributes_to_json
      sup = super
      [:accounts].concat(sup)
    end
  end
end
