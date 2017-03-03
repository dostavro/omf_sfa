require 'omf-sfa/models/component'
require 'omf-sfa/models/usb_device'

module OMF::SFA::Model
  class LteDongle < UsbDevice

    sfa_class 'lte_dongle', :can_be_referred => true, :expose_id => false, :namespace => :flex

    sfa :category, :namespace => :flex
    sfa :lte_type, :namespace => :flex
    sfa :bands, :namespace => :flex
    sfa :imsi, :namespace => :flex
    sfa :plmnid, :namespace => :flex

    # def self.exclude_from_json
    #   sup = super
    #   [:node_id].concat(sup)
    # end

    # def self.include_nested_attributes_to_json
    #   sup = super
    #   [].concat(sup)
    # end
    def to_hash_brief
      values[:config_method] = self.config_method
      values[:imsi] = self.imsi
      super
    end
  end
end
