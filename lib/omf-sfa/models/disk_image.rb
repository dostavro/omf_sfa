require 'omf-sfa/models/resource'

module OMF::SFA::Model
  class DiskImage < Resource

    one_to_many :sliver_types

    extend OMF::SFA::Model::Base::ClassMethods
    include OMF::SFA::Model::Base::InstanceMethods

    sfa_class 'disk_image', :expose_id => false
    sfa :name, attribute: true
    sfa :os, attribute: true
    sfa :version, attribute: true

    def self.exclude_from_json
      sup = super
      [:disk_image_id].concat(sup)
    end
  end
end
