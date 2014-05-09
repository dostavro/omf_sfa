require 'omf-sfa/resource/ocomponent'
require 'omf-sfa/resource/interface'
require 'omf-sfa/resource/ip'

module OMF::SFA::Resource

  class OpenflowSwitch < OComponent
    oproperty :hostname, String
    oproperty :switch_model, String
    oproperty :switch_type, String
    oproperty :openflow_version, String
    oproperty :switch_OS, String
    oproperty :datapath_id, String
    oproperty :interfaces, :Interface, :functional => false
    oproperty :of_controller_ip, :Ip
    oproperty :of_controller_port, String

    def sliver
      node.sliver
    end

    sfa_class 'switch', :can_be_referred => true, :expose_id => false

    # @see IComponent
    #
    def independent_component?
      false
    end
  end
end # OMF::SFA

