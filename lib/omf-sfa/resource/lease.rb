
require 'omf-sfa/resource/oresource'
require 'omf-sfa/resource/ocomponent'
require 'omf-sfa/resource/component_lease'

module OMF::SFA::Resource

  class Lease < OResource

    oproperty :valid_from, DataMapper::Property::Time
    oproperty :valid_until, DataMapper::Property::Time
    oproperty :status, DataMapper::Property::Enum[:pending, :accepted, :active, :past, :cancelled]

    has n, :component_leases, :child_key => [:lease_id]
    has n, :components, :model => 'OComponent', :through => :component_leases, :via => :component

    extend OMF::SFA::Resource::Base::ClassMethods
    include OMF::SFA::Resource::Base::InstanceMethods

    sfa_add_namespace :ol, 'http://nitlab.inf.uth.gr/schema/sfa/rspec/1'

    sfa_class 'lease', :namespace => :ol
    sfa :name, :attribute => true
    #sfa :uuid, :attribute => true
    sfa :valid_from, :attribute => true
    sfa :valid_until, :attribute => true

    [:pending, :accepted, :active, :past, :cancelled].each do |s|
      define_method(s.to_s + '?') do
        if self.status.eql?(s.to_s)
          true
        else
          false
        end
      end
    end

    def status
      s = oproperty_get(:status)
      if s.nil?
        oproperty_set(:status, "pending")
      else
        s
      end
    end

    # Override to_hash_brief serialization
    def to_hash_brief(opts = {})
      h = super
      components = self.components
      unless components.empty?
        h[:components] = components.map do |c|
          comp = {}
          uuid = comp[:uuid] = c.uuid.to_s
          comp[:href] = c.href(opts)
          name = c.name
          if  name && ! name.start_with?('_')
            comp[:name] = c.name
          end
          comp[:type] = c.resource_type
          {:component => comp}
        end
      end
      h
    end

    def to_sfa_ref_xml(res_el, obj2id, opts)
      if obj2id.key?(self)
        el = res_el.add_child(Nokogiri::XML::Element.new("ol:lease_ref", res_el.document))
        #el.set_attribute('component_id', self.component_id.to_s)
        el.set_attribute('id_ref', self.uuid.to_s)
      else
        self.to_sfa_xml(res_el, obj2id, opts)
      end
    end

  end
end
