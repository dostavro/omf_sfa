require 'omf-sfa/models/component'

module OMF::SFA::Model
  class Channel < Component

    sfa_class 'channel', :namespace => :ol
    sfa :frequency, :attribute => true
    sfa :client_id, :attribute => true

    def before_save
      self.available ||= true
      super
    end

    def self.exclude_from_json
      sup = super
      [:sliver_type_id, :cmc_id].concat(sup)
    end

    def self.include_nested_attributes_to_json
      sup = super
      [:leases].concat(sup)
    end
  end
end
