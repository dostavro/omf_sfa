require 'omf-sfa/models/component'
require 'omf-sfa/models/interface'
require 'omf-sfa/models/ip'

module OMF::SFA::Model
  class OpenflowSwitch < Component
    many_to_one :of_controller_ip, class: Ip
    one_to_many :interfaces

    plugin :nested_attributes
    nested_attributes :of_controller_ip, :interfaces

    sfa_class 'e_node_b', :can_be_referred => true, :expose_id => false

    def self.exclude_from_json
      sup = super
      [:of_controller_ip_id].concat(sup)
    end

    def self.include_nested_attributes_to_json
      sup = super
      [:leases, :of_controller_ip, :interfaces].concat(sup)
    end
  end
end
