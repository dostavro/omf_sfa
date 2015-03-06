require 'omf-sfa/models/resource'
require 'omf-sfa/models/disk_image'

module OMF::SFA::Model
  class SliverType < Resource

    many_to_one :disk_image
    one_to_many :nodes

    plugin :nested_attributes
    nested_attributes :disk_image

    extend OMF::SFA::Model::Base::ClassMethods
    include OMF::SFA::Model::Base::InstanceMethods

    sfa_class 'sliver_type', :expose_id => false
    sfa :name, :attribute => true
    sfa :disk_image, :inline => true

    def self.include_nested_attributes_to_json
      sup = super
      [:disk_image].concat(sup)
    end
  end
end
