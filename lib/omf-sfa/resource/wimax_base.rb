require 'omf-sfa/resource/ocomponent'

module OMF::SFA::Resource

  class WimaxBase < OComponent

    oproperty :base_model, String
    oproperty :vendor, String
    oproperty :band, String
    oproperty :vlan, String
    oproperty :mode, String

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

