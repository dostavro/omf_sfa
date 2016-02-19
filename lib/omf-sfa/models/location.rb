require 'omf-sfa/models/resource'

module OMF::SFA::Model
  class Location < Resource

    one_to_one :node
    plugin :nested_attributes
    nested_attributes :node

    extend OMF::SFA::Model::Base::ClassMethods
    include OMF::SFA::Model::Base::InstanceMethods

    sfa_class 'location', :can_be_referred => true, :expose_id => false

    sfa :country, :attribute => true
    sfa :city, :attribute => true
    sfa :longitude, :attribute => true
    sfa :latitude, :attribute => true
    sfa :position_3d, :inline => true

    def position_3d
        return nil unless self.position_3d_x && self.position_3d_y && self.position_3d_z
        el = "<ol:position_3d x=\"#{self.position_3d_x}\" y=\"#{self.position_3d_y}\" z=\"#{self.position_3d_z}\"/>"
        el_xml = Nokogiri::XML(el)
        ns = el_xml.root.add_namespace('ol', "http://nitlab.inf.uth.gr/schema/sfa/rspec/1")
        el_xml.root.namespace = ns
        el_xml.child
    end
  end
end
