require 'omf-sfa/resource/ocomponent'

module OMF::SFA::Resource

  class Cpu < OComponent

    oproperty :cpu_type, String
    oproperty :cores, Integer
    oproperty :threads, Integer
    oproperty :cache_l1, String
    oproperty :cache_l2, String

    # we have already added that in lease
    #sfa_add_namespace :ol, 'http://nitlab.inf.uth.gr/schema/sfa/rspec/1'

    #sfa_class 'cpu', :namespace => :ol
    # #sfa :number, :attribute => true
    # sfa :model, :attribute => true
    # sfa :cores, :attribute => true
    # sfa :threads, :attribute => true
    # sfa :cache_l1, :attribute => true
    # sfa :cache_l, :attribute => true

    def sliver
      node.sliver
    end

    sfa_class 'cpu', :can_be_referred => true, :expose_id => false

    #sfa :hardware_type, String, :attr_value => :name, :has_many => true
    #sfa :public_ipv4, :ip4, :attribute => true
    #sfa :model, :inline => true

    # @see IComponent
    #
    def independent_component?
      false
    end
  end
end # OMF::SFA

