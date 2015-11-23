require 'omf-sfa/models/component'
require 'omf-sfa/models/usb_device'

module OMF::SFA::Model
  class LteDongle < UsbDevice

    # sfa_class 'lte_dongle', :can_be_referred => true, :expose_id => false

    # def self.exclude_from_json
    #   sup = super
    #   [:node_id].concat(sup)
    # end

    # def self.include_nested_attributes_to_json
    #   sup = super
    #   [].concat(sup)
    # end
  end
end
