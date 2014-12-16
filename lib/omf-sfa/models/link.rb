require 'omf-sfa/models/component'

module OMF::SFA::Model
  class Link < Component

    one_to_many :interfaces


    extend OMF::SFA::Model::Base::ClassMethods
    include OMF::SFA::Model::Base::InstanceMethods

    sfa_add_namespace :omf, 'http://schema.mytestbed.net/sfa/rspec/1'

    sfa_class 'link'

    sfa :component_id, :attribute => true#, :prop_name => :urn # "urn:publicid:IDN+plc:cornell+node+planetlab3-dsl.cs.cornell.edu"
    sfa :component_name, :attribute => true
    sfa :leases, :inline => true, :has_many => true

    sfa :link_type
    sfa :component_manager, :attr_value => :name
    sfa :component_manager_id, :disabled => :true

    alias_method :component_manager, :component_manager_id
  end
end
