require 'omf-sfa/models/component'
require 'omf-sfa/models/usb_device'

module OMF::SFA::Model
  class UsrpUsbDevice < UsbDevice

    sfa_class 'usrp_usb_dongle', :can_be_referred => true, :expose_id => false, :namespace => :flex

    sfa :operating_frequency, :namespace => :flex
    sfa :antennas, :namespace => :flex
    sfa :cpu_model, :namespace => :flex
    
    # def self.exclude_from_json
    #   sup = super
    #   [:control_ip_id, :pgw_ip_id, :mme_ip_id, :epc_id].concat(sup)
    # end

    # def self.include_nested_attributes_to_json
    #   sup = super
    #   [:leases, :control_ip, :pgw_ip, :mme_ip, :epc].concat(sup)
    # end
  end
end
