require 'omf-sfa/models/component'

module OMF::SFA::Model
  class WimaxBaseStation < Component

    # oproperty :base_model, String
    # oproperty :vendor, String
    # oproperty :band, String
    # oproperty :vlan, String
    # oproperty :mode, String

    sfa_class 'wimax_base_station', :can_be_referred => true, :expose_id => false
  end
end
