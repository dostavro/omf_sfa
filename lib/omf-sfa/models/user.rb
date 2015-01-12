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

    def add_key(key)
      if key.kind_of? String
        key = OMF::SFA::Model::Key.create({ssh_key: key})
      end 
      super(key)
    end
  end
end
