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

    sfa_add_namespace :flex, 'http://nitlab.inf.uth.gr/schema/sfa/rspec/lte/1'
    sfa_class 'e_node_b', :can_be_referred => true, :expose_id => false, :namespace => :flex

    sfa :availability, :attr_value => 'now', :attr_name => 'available'
    sfa :base_model, :namespace => :flex
    sfa :vendor, :namespace => :flex
    sfa :mode, :namespace => :flex
    sfa :center_ul_frequency, :namespace => :flex
    sfa :center_dl_frequency, :namespace => :flex
    sfa :channel_bandwidth, :namespace => :flex
    sfa :number_of_antennas, :namespace => :flex
    sfa :tx_power, :namespace => :flex
    sfa :mme_sctp_port, :namespace => :flex
    sfa :control_ip, :namespace => :flex
    sfa :pgw_ip, :namespace => :flex
    sfa :mme_ip, :namespace => :flex
    sfa :sliver_id, :attribute => true

    def availability
      self.available_now?
    end

    def sliver_id
      return nil if self.parent.nil?
      return nil if self.leases.nil? || self.leases.empty?
      self.leases.first.urn
    end

    def self.exclude_from_json
      sup = super
      [:control_ip_id, :pgw_ip_id, :mme_ip_id, :epc_id, :cmc_id].concat(sup)
    end

    def self.include_nested_attributes_to_json
      sup = super
      [:leases, :control_ip, :pgw_ip, :mme_ip, :epc, :cmc].concat(sup)
    end

    def self.can_be_managed?
      true
    end
  end
end
