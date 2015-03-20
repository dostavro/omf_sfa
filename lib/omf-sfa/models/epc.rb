require 'omf-sfa/models/component'
require 'omf-sfa/models/ip'
require 'omf-sfa/models/e_node_b'


module OMF::SFA::Model
  class Epc < Component
    many_to_one :control_ip, class: Ip
    one_to_many :e_node_bs

    plugin :nested_attributes
    nested_attributes :control_ip, :e_node_bs

    sfa_class 'epc', :can_be_referred => true, :expose_id => false

    def self.exclude_from_json
      sup = super
      [:control_ip_id].concat(sup)
    end

    def self.include_nested_attributes_to_json
      sup = super
      [:leases, :control_ip, :e_node_bs].concat(sup)
    end
  end
end
