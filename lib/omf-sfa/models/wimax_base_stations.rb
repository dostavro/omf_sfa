require 'omf-sfa/models/component'

module OMF::SFA::Model
  class WimaxBaseStation < Component

    # oproperty :base_model, String
    # oproperty :vendor, String
    # oproperty :band, String
    # oproperty :vlan, String
    # oproperty :mode, String

    sfa_class 'wimax_base_station', :can_be_referred => true, :expose_id => false


    def self.include_nested_attributes_to_json
      sup = super
      [:leases].concat(sup)
    end

    def self.can_be_managed?
      true
    end
  end
end
