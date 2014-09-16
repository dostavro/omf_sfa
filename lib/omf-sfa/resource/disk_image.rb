require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/sfa_base'

module OMF::SFA::Resource

  class DiskImage < OResource

    # oproperty :name, String
    oproperty :os, String
    oproperty :version, String

    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods

    sfa_class 'disk_image', :expose_id => false
    sfa :name, attribute: true
    sfa :os, attribute: true
    sfa :version, attribute: true
  end
end # OMF::SFA

