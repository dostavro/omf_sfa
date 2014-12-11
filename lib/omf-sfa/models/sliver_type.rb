require 'models/resource'

module OMF::SFA::Model
  class SliverType < Resource

    many_to_one :disk_image
    one_to_many :nodes

    extend OMF::SFA::Model::Base::ClassMethods
    include OMF::SFA::Model::Base::InstanceMethods

    sfa_class 'sliver_type', :expose_id => false
    sfa :name, :attribute => true
    sfa :disk_image, :inline => true
  end
end
