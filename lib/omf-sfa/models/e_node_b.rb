require 'omf-sfa/models/component'
require 'omf-sfa/models/ip'
require 'omf-sfa/models/epc'

module OMF::SFA::Model
  class ENodeB < Component
    many_to_one :control_ip, class: Ip
    many_to_one :pgw_ip, class: Ip
    many_to_one :mme_ip, class: Ip
    many_to_one :epc
    many_to_one :cmc

    plugin :nested_attributes
    nested_attributes :control_ip, :pgw_ip, :mme_ip, :epc, :cmc

    sfa_class 'e_node_b', :can_be_referred => true, :expose_id => false

    def self.exclude_from_json
      sup = super
      [:control_ip_id, :pgw_ip_id, :mme_ip_id, :epc_id, :cmc_id].concat(sup)
    end

    def self.include_nested_attributes_to_json
      sup = super
      [:leases, :control_ip, :pgw_ip, :mme_ip, :epc, :cmc].concat(sup)
    end
  end
end
