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

    sfa_class 'wimax_base', :can_be_referred => true, :expose_id => false
    #
    def independent_component?
      false
    end
  end
end # OMF::SFA

