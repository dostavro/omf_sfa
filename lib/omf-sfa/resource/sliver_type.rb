require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/disk_image'
require 'omf-sfa/resource/sfa_base'

module OMF::SFA::Resource

  class SliverType < OResource

    # oproperty :name, String
    oproperty :disk_image, :DiskImage

    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods

    sfa_class 'sliver_type', :expose_id => false
    sfa :name, :attribute => true
    sfa :disk_image, :inline => true
  end
end # OMF::SFA

