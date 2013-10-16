
require 'nokogiri'
require 'time'
require 'omf_common/lobject'

require 'omf-sfa/resource/gurn'
require 'omf-sfa/resource/constants'



module OMF::SFA
  module Resource

    module Base

      SFA_NAMESPACE_URI = "http://www.geni.net/resources/rspec/3"

      module ClassMethods

        def default_domain
          Constants.default_domain
        end

        def default_component_manager_id
          Constants.default_component_manager_id
        end

        @@sfa_defs = {}
        @@sfa_namespaces = {}
        @@sfa_classes = {}
        @@sfa_class_props = {}
        @@sfa_name2class = {}

        # Add the class in the 'sfa_classes' and add a prefix to the name
        # if a namespace is given.
        #
        # @param [String] name Name of the sfa class
        # @param [Hash] opts Options of this sfa class
        # @option opts [Symbol] :namespace The prefix of the namespace. Namespaces should be added with the 'sfa_add_namespace' method.
        # @option opts [Boolean] :expose_id If false, then do not expose 'id' or 'component_id' through SFA
        # @option opts [Boolean] :can_be_referred If true, then this element can be referred via its 'component_id' or 'id', instead of repeating its definition every time
        #
        def sfa_class(name = nil, opts = {})
          if name
            name = _sfa_add_ns(name, opts)
            @@sfa_classes[self] = name
            @@sfa_class_props[self] = opts
            @@sfa_name2class[name] = self
          else
            @@sfa_classes[self]
          end
        end

        # Add a namespace with its prefix in the 'sfa_namespaces'
        #
        def sfa_add_namespace(prefix, urn)
          @@sfa_namespaces[prefix] = urn
        end

        # Add all the namespaces to the root element of the XML document
        #
        def sfa_add_namespaces_to_document(doc)
          root = doc.root
          root.add_namespace(nil, SFA_NAMESPACE_URI)
          @@sfa_namespaces.each do |name, uri|
            root.add_namespace(name.to_s, uri) #'omf', 'http://tenderlovemaking.com')
          end
        end

        # Define an SFA property
        #
        # @param [Symbol] name name of resource in RSpec
        # @param [Hash] opts options to further describe mappings
        # @option opts [Boolean] :inline If true, then given a parent element, a property name and value, this will result in <parent_element>value</parent_element>
        # @option opts [Boolean] :attribute If true, then given a parent element, a property name and value, this will result in <parent_element property_name="value"/>
        # @option opts [String] :attr_value If set, then the property will be a new element with an attribute named by the :attr_value: <property_name attr_value_content="property_value"/>
        # @option opts [Boolean] :has_manny If true, can occur multiple times, forming an array
        # @option opts [Boolean] :disabled If true, then this property will not be exposed through SFA. Useful for disabling inherited properties when needed. (e.g. link)
        # @option opts [String] :default Give a default value to this property
        #
        def sfa(name, opts = {})
          name = name.to_s
          props = sfa_defs() # get all the sfa properties of this class
          props[name] = opts
          # recalculate sfa properties of the descendants
          descendants.each do |c| c.sfa_defs(false) end
        end

        # Return the properties of this SFA class
        #
        def sfa_class_props
          @@sfa_class_props[self]
        end

        # opts:
        #   :valid_for - valid [sec] from now
        #
        def sfa_advertisement_xml(resources, opts = {})

          # arrange resources with the following order: lease, channel, node, link
          # leases and interfaces should be declared first and later on referenced
          # inside nodes and links respectively
          leases = resources.select {|v| v.resource_type == 'lease'}
          channels = resources.select {|v| v.resource_type == 'channel'}
          nodes = resources.select {|v| v.resource_type == 'node'}
          rest = resources - leases - channels - nodes
          resources = leases + channels + nodes + rest

          doc = Nokogiri::XML::Document.new
          #<rspec expires="2011-09-13T09:07:09Z" generated="2011-09-13T09:07:09Z" type="advertisement" xmlns="http://www.geni.net/resources/rspec/3" xmlns:ol="http://nitlab.inf.uth.gr/schema/sfa/rspec/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.geni.net/resources/rspec/3 http://www.geni.net/resources/rspec/3/ad.xsd http://nitlab.inf.uth.gr/schema/sfa/rspec/1 http://nitlab.inf.uth.gr/schema/sfa/rspec/1/ad-reservation.xsd">
          root = doc.add_child(Nokogiri::XML::Element.new('rspec', doc))
          root.add_namespace(nil, SFA_NAMESPACE_URI)
          root.add_namespace('xsi', "http://www.w3.org/2001/XMLSchema-instance")

          #opts[:type] = 'advertisement' unless opts[:type]
          #if opts[:type] == 'manifest'
          #  schema = 'manifest.xsd'
          #else
          #  schema = 'ad.xsd'
          #end
          root['xsi:schemaLocation'] = "#{SFA_NAMESPACE_URI} #{SFA_NAMESPACE_URI}/ad.xsd #{@@sfa_namespaces[:ol]} #{@@sfa_namespaces[:ol]}/ad-reservation.xsd"
          @@sfa_namespaces.each do |prefix, urn|
            root.add_namespace(prefix.to_s, urn)
          end

          root.set_attribute('type', 'advertisement')
          now = Time.now
          root.set_attribute('generated', now.iso8601)
          root.set_attribute('expires', (now + (opts[:valid_for] || 600)).iso8601)

          obj2id = {}
          _to_sfa_xml(resources, root, obj2id, opts)
        end

        def sfa_manifest_xml(resources, opts = {})
          warn "Not implemented yet"
        end

        def create_from_rspec(resource_el, resources, manager)

          if client_id_attr = resource_el.attributes['client_id']
            uuid = UUIDTools::UUID.parse(client_id_attr.value)
            type = resource_el.name
            resource = manager.find_resource({:uuid => uuid}, authorizer) # wouldn't know what to create
          elsif comp_id_attr = resource_el.attributes['component_id']
            comp_id = comp_id_attr.value
            comp_gurn = OMF::SFA::Resource::GURN.parse(comp_id)
            #if uuid = comp_gurn.uuid
            #  resource_descr = {:uuid => uuid}
            #else
            #  resource_descr = {:name => comp_gurn.short_name}
            #end
            resource_descr = {:urn => comp_gurn}
            resource = find_or_create_resource_for_account(resource_descr, comp_gurn.type, {}, authorizer)
            unless resource
              raise UnknownResourceException.new "Resource '#{resource_el.to_s}' is not available or doesn't exist"
            end
          end

          if id_attr = resource_el.attributes['id']
            resource = OMF::SFA::Resource::OResource.first(uuid: id_attr)
            resources << OMF::SFA::Resource::OResource.create_from_rspec(resource, resource_el)
          elsif component_id = resource_el.attributes['component_id']
            if (/\w+_ref$/ =~ resource_el.name) == 0 # "resource_ref"
              # This is a reference, the resource has been already created

            else
              resources << OMF::SFA::OResource.first(component_id: component_id)
            end
          elsif client_id = resource_el.attributes['client_id']
            resources[client_id]
          end

        end

        def from_sfa(resource_el)
          resource = nil
          uuid = nil
          comp_gurn = nil
          if uuid_attr = (resource_el.attributes['uuid'] || resource_el.attributes['idref'])
            uuid = UUIDTools::UUID.parse(uuid_attr.value)
            resource = OMF::SFA::Resource::OResource.first(:uuid => uuid)
            return resource.from_sfa(resource_el)
          end

          if comp_id_attr = resource_el.attributes['component_id']
            comp_id = comp_id_attr.value
            comp_gurn = OMF::SFA::Resource::GURN.parse(comp_id)
            #begin
            if uuid = comp_gurn.uuid
              resource = OMF::SFA::Resource::OResource.first(:uuid => uuid)
              return resource.from_sfa(resource_el)
            end
            if resource = OMF::SFA::Resource::OComponent.first(:urn => comp_gurn)
              return resource.from_sfa(resource_el)
            end
          else
            # need to create a comp_gurn (the link is an example of that)
            unless sliver_id_attr = resource_el.attributes['sliver_id']
              raise "Need 'sliver_id' for resource '#{resource_el}'"
            end
            sliver_gurn = OMF::SFA::Resource::GURN.parse(sliver_id_attr.value)
            unless client_id_attr = resource_el.attributes['client_id']
              raise "Need 'client_id' for resource '#{resource_el}'"
            end
            client_id = client_id_attr.value
            opts = {
              :domain => sliver_gurn.domain,
              :type => resource_el.name  # TODO: This most likely will break with NS
            }
            comp_gurn = OMF::SFA::Resource::GURN.create("#{sliver_gurn.short_name}:#{client_id}", opts)
            if resource = OMF::SFA::Resource::OComponent.first(:urn => comp_gurn)
              return resource.from_sfa(resource_el)
            end
          end

          # Appears the resource doesn't exist yet, let's see if we can create one
          type = comp_gurn.type
          if res_class = @@sfa_name2class[type]
            resource = res_class.new(:name => comp_gurn.short_name)
            return resource.from_sfa(resource_el)
          end
          raise "Unknown resource type '#{type}' (#{@@sfa_name2class.keys.join(', ')})"
        end

        def _to_sfa_xml(resources, root, obj2id, opts = {})
          if resources.kind_of? Enumerable
            resources.each do |r|
              _to_sfa_xml(r, root, obj2id, opts)
            end
          else
            resources.to_sfa_xml(root, obj2id, opts)
          end
          root.document
        end

        # Return all the property definitions for this class.
        # It returns also the properties that have been inherited.
        #
        # +cached+ - If false, recalculate
        #
        def sfa_defs(cached = true)
          unless cached && props = @@sfa_defs[self]
            # this assumes that all the properties of the super classes are already set
            props = {}
            klass = self
            while klass = klass.superclass
              if sp = @@sfa_defs[klass]
                props = sp.merge(props)
              end
            end
            #puts "PROP #{self}:#{props.keys.inspect}"
            @@sfa_defs[self] = props
          end
          props
        end

        # UNUSED METHODS
        #
        #def sfa_def_for(name)
        #  sfa_defs()[name.to_s]
        #end

        #def sfa_cast_property_value(value, property_name, context, type = nil)
        #  name = property_name.to_s
        #  unless type
        #    pdef = sfa_def_for(name)
        #    raise "Unknow SFA property '#{name}'" unless pdef
        #    type = pdef[:type]
        #  end
        #  if type.kind_of?(Symbol)
        #    if type == :boolean
        #      unless value.kind_of?(TrueClass) || value.kind_of?(FalseClass)
        #        raise "Wrong type for '#{name}', is #{value.type}, but should be #{type}"
        #      end
        #    else
        #      raise "Unknown type '#{type}', use real Class"
        #    end
        #  elsif !(value.kind_of?(type))
        #    if type.respond_to? :sfa_create
        #      value = type.sfa_create(value, context)
        #    else
        #      raise "Wrong type for '#{name}', is #{value.class}, but should be #{type}"
        #    end
        #     #puts "XXX>>> #{name}--#{! value.kind_of?(type)}--#{value.class}||#{type}||#{pdef.inspect}"

        #  end
        #  value
        #end

        # Add the corresponding prefix to the name given a namespace
        #
        def _sfa_add_ns(name, opts = {})
          if prefix = opts[:namespace]
            unless @@sfa_namespaces[prefix]
              raise "Unknown namespace '#{prefix}'"
            end
            name = "#{prefix}:#{name}"
          end
          name
        end

        def descendants
          result = []
          ObjectSpace.each_object(Class) do |klass|
            result = result << klass if klass < self
          end
          result
        end

      end # ClassMethods

      module InstanceMethods

        # Returns the component id of this resource if exists.
        # If not, then return its URN or create a new one containing its name.
        #
        def component_id
          unless id = attribute_get(:component_id)
            #self.component_id ||= GURN.create(self.uuid.to_s, self)
            #return GURN.create(self.uuid.to_s, { :model => self.class })
            if self.urn
              return GURN.create(self.urn, { :model => self.class })
            else
              return GURN.create(self.name, { :model => self.class })
            end
          end
          id
        end

        # Returns the component manager id of this resource if exists.
        # Otherwise, it returns the default component manager id.
        #
        def component_manager_id
          unless uuid = attribute_get(:component_manager_id)
            return self.class.default_component_manager_id
          end
          uuid
        end

        # Returns the default domain which is either defined in
        # 'Constants' or in the configuration file under 'etc/'
        #
        def default_domain
          self.class.default_domain()
        end

        # Returns the uuid of the resource. It can be overridden
        # if a different id needs to be exposed through SFA
        #
        def sfa_id()
          self.uuid.to_s
        end

        # Returns what it says, the SFA class of the resource
        #
        def sfa_class()
          self.class.sfa_class()
        end

        # Returns the XML name that is going to be used in the
        # element of the RSpecs
        #
        def _xml_name()
          if name = self.sfa_class
            return name
          end
          self.class.name.gsub('::', '_')
        end

        # UNUSED METHOD
        #
        #def to_sfa_short_xml(parent)
        #  n = parent.add_child(Nokogiri::XML::Element.new('resource', parent.document))
        #  n.set_attribute('type', _xml_name())
        #  n.set_attribute('status', 'unimplemented')
        #  n.set_attribute('name', component_name())
        #  n
        #end

        # Return all SFA related properties as a hash
        #
        # +opts+
        #   :detail - detail to reveal about resource 0..min, 99 .. max
        #
        def to_sfa_hash(href2obj = {}, opts = {})
          res = to_sfa_hash_short(opts)
          #res['comp_gurn'] = self.urn # this is the same with the component_id
          href = res['href']
          if obj = href2obj[href]
            # have described myself before
            raise "Different object with same href '#{href}'" unless obj == self
            return res
          end
          href2obj[href] = self
          res['sfa_class'] = sfa_class()

          defs = self.class.sfa_defs()
          #debug ">> #{defs.inspect}"
          defs.keys.sort.each do |key|
            next if key.start_with?('_')
            pdef = defs[key]
            pname = pdef[:prop_name] || key
            value = send(pname.to_sym)
            if value.nil?
              value = pdef[:default]
            end
            #debug "!#{key} => '#{value}' - #{self}"
            unless value.nil?
              method = "_to_sfa_#{key}_property_hash".to_sym
              if self.respond_to? method
                res[k] = send(method, value, pdef, href2obj, opts)
                #debug ">>>> #{key}::#{res[key]}"
              else
                res[key] = _to_sfa_property_hash(value, pdef, href2obj, opts)
              end
            end
          end
          res
        end

        def to_sfa_hash_short(opts = {})
          uuid = self.uuid.to_s
          href_prefix = opts[:href_prefix] ||= default_href_prefix
          {
            'name' => self.name,
            'uuid' => uuid,
            'sfa_class' => sfa_class(),
            'href' => "#{href_prefix}/#{uuid}"
          }
        end

        def _to_sfa_property_hash(value, pdef, href2obj, opts)
          if !value.kind_of?(String) && value.kind_of?(Enumerable)
            value.collect do |v|
              if v.respond_to? :to_sfa_hash
                v.to_sfa_hash_short(opts)
              else
                v.to_s
              end
            end
          else
            value.to_s
          end
        end

        #
        # +opts+
        #   :detail - detail to reveal about resource 0..min, 99 .. max
        #
        def to_sfa_xml(parent = nil, obj2id = {}, opts = {})
          if parent.nil?
            parent = Nokogiri::XML::Document.new
            # first time around, add namespace
            self.class.sfa_add_namespaces_to_document(parent)
          end
          _to_sfa_xml(parent, obj2id, opts)
          parent
        end

        def _to_sfa_xml(parent, obj2id, opts)

          defs = self.class.sfa_defs()

          debug "SFA opts: #{opts}"
          debug "SFA defs: #{defs}"

          class_props = self.class.sfa_class_props
          if (id = obj2id[self]) && class_props[:can_be_referred] == true
            # make a reference instead of having the full description
            _to_sfa_ref_xml(parent, opts, defs)
            return parent
          end

          new_element = parent.add_child(Nokogiri::XML::Element.new(_xml_name(), parent.document))

          id = sfa_id()
          obj2id[self] = id

          unless class_props[:expose_id] == false
            new_element.set_attribute('id', id) if defs['component_id'].nil?
          end

          defs.keys.sort.each do |key|
            next if key.start_with?('_')
            pdef = defs[key]
            next if pdef[:disabled]

            value = send(key.to_sym)
            #debug "#{key} <#{value}> #{pdef.inspect}"
            if value.nil?
              value = pdef[:default]
            end
            unless value.nil?
              if value.is_a?(Time)
                value = value.xmlschema # xs:dateTime
              end
              _to_sfa_property_xml(key, value, new_element, pdef, obj2id, opts)
            end
          end
          new_element
        end

        def _to_sfa_ref_xml(parent, opts, defs)
          el = parent.add_child(Nokogiri::XML::Element.new("#{_xml_name()}_ref", parent.document))

          if defs['component_id'].nil?
            el.set_attribute('id_ref', self.uuid.to_s)
          else
            el.set_attribute('component_id', self.component_id.to_s)
          end
        end

        def _to_sfa_property_xml(pname, value, res_el, pdef, obj2id, opts)

          pname = self.class._sfa_add_ns(pname, pdef)

          if pdef[:attribute]
            res_el.set_attribute(pname, value.to_s)
          elsif aname = pdef[:attr_value]
            el = res_el.add_child(Nokogiri::XML::Element.new(pname, res_el.document))
            el.set_attribute(aname, value.to_s)
          else
            if pdef[:inline] == true
              cel = res_el
            else
              cel = res_el.add_child(Nokogiri::XML::Element.new(pname, res_el.document))
            end
            if !value.kind_of?(String) && value.kind_of?(Enumerable)
              value.each do |v|
                if v.respond_to?(:to_sfa_xml)
                  v.to_sfa_xml(cel, obj2id, opts)
                else
                  el = cel.add_child(Nokogiri::XML::Element.new(pname, cel.document))
                  el.content = v.to_s
                end
              end
            else
              if value.respond_to?(:to_sfa_xml)
                value.to_sfa_xml(cel, obj2id, opts)
              else
                cel.content = value.to_s
              end
            end
          end
        end

        def from_sfa(resource_el)
          els = {} # this doesn't work with generic namespaces
          resource_el.children.each do |el|
            next unless el.is_a? Nokogiri::XML::Element
            unless ns = el.namespace
              raise "Missing namespace declaration for '#{el}'"
            end
            unless ns.href == SFA_NAMESPACE_URI
              puts "WARNING: '#{el.name}' Can't handle non-default namespaces '#{ns.href}'"
            end
            (els[el.name] ||= []) << el
          end

          self.class.sfa_defs.each do |name, props|
            mname = "_from_sfa_#{name}_property_xml".to_sym
            if self.respond_to?(mname)
              send(mname, resource_el, props)
            elsif props[:attribute] == true
              next if name.to_s == 'component_name' # skip that one for the moment
              if v = resource_el.attributes[name]
                #puts "#{name}::#{name.class} = #{v}--#{v.class}"
                name = props[:prop_name] || name
                send("#{name}=".to_sym, v.text)
              end
            elsif arr = els[name.to_s]
              #puts "Handling #{name} -- #{props}"
              name = props[:prop_name] || name
              arr.each do |el|
                #puts "#{name} = #{el.text}"
                send("#{name}=".to_sym, el.text)
              end
            # else
              # puts "Don't know how to handle '#{name}' (#{props})"
            end
          end
          unless self.save
            raise "Couldn't save resource '#{self}'"
          end
          return self
        end
      end # InstanceMethods

    end # Base
  end # Resource
end # OMF::SFA

#DataMapper::Model.append_extensions(OMF::SFA::Resource::Base::ClassMethods)
#DataMapper::Model.append_inclusions(OMF::SFA::Resource::Base::InstanceMethods)
