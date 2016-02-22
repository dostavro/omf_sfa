require 'omf-sfa/models/component'

module OMF::SFA::Model
  class UsbDevice < Component
    many_to_one :node 

    # sfa_class 'usb_device', :can_be_referred => true, :expose_id => false

    # def self.exclude_from_json
    #   sup = super
    #   [:node_id].concat(sup)
    # end

    # def self.include_nested_attributes_to_json
    #   sup = super
    #   [:node].concat(sup)
    # end

    def self.can_be_managed?
      true
    end
  end
end
