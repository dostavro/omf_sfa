require 'omf-sfa/models/resource'
require 'omf-sfa/models/lease'

module OMF::SFA::Model
  class Component < Resource
    many_to_one :parent, :class=>self
    one_to_many :children, :key=>:parent_id, :class=>self

    # Note that :left_key refers to the foreign key pointing to the
    # current table, and :right_key the foreign key pointing to the
    # associated table.
    many_to_many :leases, :left_key=>:component_id, :right_key=>:lease_id,
    :join_table=>:components_leases

    extend OMF::SFA::Model::Base::ClassMethods
    include OMF::SFA::Model::Base::InstanceMethods

    sfa_add_namespace :omf, 'http://schema.mytestbed.net/sfa/rspec/1'
      #sfa_add_namespace :ol, 'http://nitlab.inf.uth.gr/schema/sfa/rspec/1'

    sfa :component_id, :attribute => true#, :prop_name => :urn # "urn:publicid:IDN+plc:cornell+node+planetlab3-dsl.cs.cornell.edu"
    sfa :component_manager_id, :attribute => true#, :prop_name => :component_manager_gurn # "urn:publicid:IDN+plc+authority+am"
    sfa :component_name, :attribute => true # "plane
    sfa :leases, :inline => true, :has_many => true
  end #Class
end #OMF::SFA::Model
