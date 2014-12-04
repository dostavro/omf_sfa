require 'omf-sfa/resource/sfa_base'

module OMF::SFA::Resource

  class Location < OResource

    oproperty :country, String
    oproperty :city, String
    oproperty :longitude, Integer
    oproperty :latitude, Integer

    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods

    sfa_class 'location', :can_be_referred => true, :expose_id => false

    sfa :country, :attribute => true
    sfa :city, :attribute => true
    sfa :longitude, :attribute => true
    sfa :latitude, :attribute => true

    # @see IComponent
    #
    def independent_component?
      false
    end

  end

end # OMF::SFA::Resource

