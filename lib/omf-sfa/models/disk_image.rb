require 'omf-sfa/models/resource'

module OMF::SFA::Model
  class Disk_image < Resource

    one_to_many :sliver_types

    extend OMF::SFA::Model::Base::ClassMethods
    include OMF::SFA::Model::Base::InstanceMethods

    sfa_class 'disk_image', :expose_id => false
    sfa :name, attribute: true
    sfa :os, attribute: true
    sfa :version, attribute: true
  end
end
