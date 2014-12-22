require 'omf-sfa/models/component'
require 'omf-sfa/models/cmc'
require 'omf-sfa/models/sliver_type'

module OMF::SFA::Model
  class Node < Component

    one_to_many :interfaces
    one_to_many :cpus
    many_to_one :cmc
    one_to_one :location
    many_to_one :sliver_type

    plugin :nested_attributes
    nested_attributes :interfaces, :cpus, :cmc, :location, :sliver_type

    sfa_class 'node'
    sfa :hardware_type, :attr_value => 'name'
    sfa :available, :attr_value => 'now'  # <available now="true">
    sfa :sliver_type, :inline => true
    sfa :interfaces, :inline => true, :has_many => true
    sfa :exclusive, :attribute => true
    sfa :location, :inline => true
    sfa :boot_state, :attribute => true

    def before_save
      self.available ||= true
      super
    end

    def self.exclude_from_json
      sup = super
      [:sliver_type_id, :cmc_id].concat(sup)
    end

    def self.include_nested_attributes_to_json
      sup = super
      [:interfaces, :cpus, :cmc, :location, :sliver_type].concat(sup)
    end
  end
end
