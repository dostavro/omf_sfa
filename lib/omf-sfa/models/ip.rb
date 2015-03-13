require 'omf-sfa/models/resource'

module OMF::SFA::Model
  class Ip < Resource

    many_to_one :interface
    one_to_one :cmc
    one_to_one :e_node_b

    plugin :nested_attributes
    nested_attributes :interface, :cmc, :e_node_b

    extend OMF::SFA::Model::Base::ClassMethods
    include OMF::SFA::Model::Base::InstanceMethods

    sfa_class 'ip', :expose_id => false
    sfa :address, :attribute => true
    sfa :netmask, :attribute => true
    sfa :ip_type, :attribute => true

    def self.exclude_from_json
      sup = super
      [:interface_id].concat(sup)
    end
  end
end
