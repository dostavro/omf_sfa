require 'omf-sfa/models/component'

module OMF::SFA::Model
  class Link < Component

    one_to_many :interfaces


    extend OMF::SFA::Model::Base::ClassMethods
    include OMF::SFA::Model::Base::InstanceMethods

    sfa_add_namespace :omf, 'http://schema.mytestbed.net/sfa/rspec/1'

    sfa_class 'link'

    sfa :component_id, :attribute => true#, :prop_name => :urn # "urn:publicid:IDN+plc:cornell+node+planetlab3-dsl.cs.cornell.edu"
    sfa :component_name, :attribute => true
    sfa :leases, :inline => true, :has_many => true

    sfa :link_type
    sfa :component_manager, :attr_value => :name
    sfa :component_manager_id, :disabled => :true

    alias_method :component_manager, :component_manager_id

    def self.exclude_from_json
      sup = super
      [].concat(sup)
    end

    def self.include_nested_attributes_to_json
      sup = super
      [:interfaces].concat(sup)
    end

    def to_hash
      values.reject! { |k, v| v.nil?}
      values[:interfaces] = []
      self.interfaces.each do |interface|
        values[:interfaces] << interface.to_hash_brief
      end
      excluded = self.class.exclude_from_json
      values.reject! { |k, v| excluded.include?(k)}
      values
    end

    def to_hash_brief
      val = {}
      val[:name] = self.name
      val[:uuid] = self.uuid
      val[:urn] = self.urn
      val[:resource_type] = self.resource_type
      val[:exclusive] = self.exclusive
      val[:connects] = []
      self.interfaces.each do |interface|
        tmp = interface.node.to_hash_brief if interface.node
        tmp = interface.openflow_switch.to_hash_brief if interface.openflow_switch
        tmp = interface.usrp_ethernet_device.to_hash_brief if interface.usrp_ethernet_device
        val[:connects] << tmp
      end
      val.reject! { |k, v| v.nil?}
      val
    end
  end
end
