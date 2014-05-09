require 'omf-sfa/resource/ocomponent'
require 'omf-sfa/resource/ip'

module OMF::SFA::Resource

  class LteBase < OComponent

    oproperty :base_model, String
    oproperty :vendor, String
    oproperty :band, String
    oproperty :mode, String
    oproperty :ip_ap, :Ip
    oproperty :ip_epc, :Ip
    oproperty :apn, String
    oproperty :ip_pdn_gw, :Ip

    def sliver
      node.sliver
    end

    sfa_class 'LteBase'#, :can_be_referred => true, :expose_id => false
    #
    sfa :base_model
    sfa :vendor
    sfa :band
    sfa :mode
    sfa :ip_ap
    sfa :ip_epc
    sfa :apn
    sfa :ip_pdn_gw

    def independent_component?
      false
    end
  end
end # OMF::SFA

