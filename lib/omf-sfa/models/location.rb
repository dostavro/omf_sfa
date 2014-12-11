require 'models/resource'

module OMF::SFA::Model
  class Location < Resource

    many_to_one :node

    extend OMF::SFA::Model::Base::ClassMethods
    include OMF::SFA::Model::Base::InstanceMethods

    sfa_class 'location', :can_be_referred => true, :expose_id => false

    sfa :country, :attribute => true
    sfa :city, :attribute => true
    sfa :longitude, :attribute => true
    sfa :latitude, :attribute => true
  end
end
