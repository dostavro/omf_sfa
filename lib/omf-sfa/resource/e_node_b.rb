require 'omf-sfa/resource/ocomponent'
require 'omf-sfa/resource/ip'

module OMF::SFA::Resource

  class ENodeB < OComponent

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

    sfa_add_namespace :nitos, 'http://nitlab.inf.uth.gr/schema/sfa/rspec/ext'
    sfa_class 'ENodeB', :namespace => :nitos#, :can_be_referred => true, :expose_id => false
    #
    sfa :base_model, :namespace => :nitos
    sfa :vendor, :namespace => :nitos
    sfa :band, :namespace => :nitos
    sfa :mode, :namespace => :nitos
    sfa :ip_ap, :namespace => :nitos
    sfa :ip_epc, :namespace => :nitos
    sfa :apn, :namespace => :nitos
    sfa :ip_pdn_gw, :namespace => :nitos

    def independent_component?
      false
    end
  end
end # OMF::SFA