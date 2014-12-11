require 'models/resource'
require 'models/component'

module OMF::SFA::Model
  class Lease < Resource
    many_to_many :components, :left_key=>:lease_id, :right_key=>:component_id,
    :join_table=>:components_leases


    extend OMF::SFA::Model::Base::ClassMethods
    include OMF::SFA::Model::Base::InstanceMethods

    sfa_add_namespace :ol, 'http://nitlab.inf.uth.gr/schema/sfa/rspec/1'

    sfa_class 'lease', :namespace => :ol, :can_be_referred => true
    sfa :valid_from, :attribute => true
    sfa :valid_until, :attribute => true
  end
end
