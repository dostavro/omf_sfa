require 'nokogiri'

module OMF::SFA::Model
  module Base

    SFA_NAMESPACE_URI = "http://www.geni.net/resources/rspec/3"

    module ClassMethods

      def default_component_manager_id
        Constants.default_component_manager_id
      end

      @@sfa_namespaces = {}
      @@sfa_defs = {}
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

      # Add a namespace with its prefix in the 'sfa_namespaces'
      #
      def sfa_add_namespace(prefix, urn)
        @@sfa_namespaces[prefix] = urn
      end

      # Define an SFA property
      #
      # @param [Symbol] name name of resource in RSpec
      # @param [Hash] opts options to further describe mappings
      # @option opts [Boolean] :inline If true, then given a parent element, a property name and a value, this will result in <parent_element>value</parent_element>
      # @option opts [Boolean] :attribute If true, then given a parent element, a property name and a value, this will result in <parent_element property_name="value"/>
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
        descendants.each { |c| c.sfa_defs(false) }
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
          @@sfa_defs[self] = props
        end
        props
      end

      def descendants
        result = []
        ObjectSpace.each_object(Class) do |klass|
          result = result << klass if klass < self
        end
        result
      end

      def sfa_response_xml(resources, opts = {type: 'advertisement'})
        doc = Nokogiri::XML::Document.new
        root = doc.add_child(Nokogiri::XML::Element.new('rspec', doc))
        root.add_namespace(nil, SFA_NAMESPACE_URI)
        root.add_namespace('xsi', "http://www.w3.org/2001/XMLSchema-instance")
        root.set_attribute('type', opts[:type])

        @@sfa_namespaces.each do |prefix, urn|
          root.add_namespace(prefix.to_s, urn)
        end

        case opts[:type].downcase
        when 'advertisement'
          root['xsi:schemaLocation'] = "#{SFA_NAMESPACE_URI} #{SFA_NAMESPACE_URI}/ad.xsd " +
          "#{@@sfa_namespaces[:ol]} #{@@sfa_namespaces[:ol]}/ad-reservation.xsd"

          now = Time.now
          root.set_attribute('generated', now.iso8601)
          root.set_attribute('expires', (now + (opts[:valid_for] || 600)).iso8601)
        when 'manifest'
          root['xsi:schemaLocation'] = "#{SFA_NAMESPACE_URI} #{SFA_NAMESPACE_URI}/manifest.xsd " +
          "#{@@sfa_namespaces[:ol]} #{@@sfa_namespaces[:ol]}/request-reservation.xsd"

          now = Time.now
          root.set_attribute('generated', now.iso8601)
        else
          raise "Unknown SFA response type: '#{opts[:type]}'"
        end

        obj2id = {}
        _to_sfa_xml(resources, root, obj2id, opts)
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

      # Return the properties of this SFA class
      #
      def sfa_class_props
        @@sfa_class_props[self]
      end

    end #ClassMethods

    module InstanceMethods

      attr_accessor :client_id

      def to_sfa_xml(parent, obj2id, opts)
        defs = self.class.sfa_defs()
        class_props = self.class.sfa_class_props

        if class_props[:can_be_referred] == true && obj2id[self]
          # insert a reference instead of providing the full description
          _to_sfa_ref_xml(parent, opts, defs)
          return parent
        end

        new_element = parent.add_child(Nokogiri::XML::Element.new(_xml_name(), parent.document))

        id = sfa_id()
        obj2id[self] = id

        unless class_props[:expose_id] == false
          new_element.set_attribute('id', id) if defs['component_id'].nil?
        end

        if opts[:type].downcase.eql?('manifest') && self.client_id
          new_element.set_attribute('client_id', self.client_id)
        end

        defs.keys.sort.each do |key|

          prop_opts = defs[key]
          next if prop_opts[:disabled]

          value = send(key.to_sym)

          if value.nil?
            value = prop_opts[:default]
          else
            if value.is_a?(Time)
              value = value.xmlschema # xs:dateTime
            end
            _to_sfa_property_xml(key, value, new_element, prop_opts, obj2id, opts)
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

      # Returns the XML name that is going to be used in the
      # element of the RSpecs
      #
      def _xml_name()
        if name = self.sfa_class
          return name
        end
        self.class.name.gsub('::', '_')
      end

      # Returns the uuid of the resource. It can be overridden
      # if a different id needs to be exposed through SFA
      #
      def sfa_id()
        self.uuid.to_s
      end

      def _to_sfa_property_xml(prop_name, value, res_el, prop_opts, obj2id, opts)

        prop_name = self.class._sfa_add_ns(prop_name, prop_opts)

        if prop_opts[:attribute]
          res_el.set_attribute(prop_name, value.to_s)
        elsif attr_name = prop_opts[:attr_value]
          el = res_el.add_child(Nokogiri::XML::Element.new(prop_name, res_el.document))
          el.set_attribute(attr_name, value.to_s)
        else
          if prop_opts[:inline] == true
            prop_el = res_el
          else
            prop_el = res_el.add_child(Nokogiri::XML::Element.new(prop_name, res_el.document))
          end
          if !value.kind_of?(String) && value.kind_of?(Enumerable) && !value.kind_of?(Nokogiri::XML::Element)
            value.each do |v|
              if v.respond_to?(:to_sfa_xml)
                v.to_sfa_xml(prop_el, obj2id, opts)
              else
                el = prop_el.add_child(Nokogiri::XML::Element.new(prop_name, prop_el.document))
                el.content = v.to_s
              end
            end
          else
            if value.respond_to?(:to_sfa_xml)
              value.to_sfa_xml(prop_el, obj2id, opts)
            elsif value.kind_of?(Nokogiri::XML::Element)
              prop_el.add_child(value)
            else
              prop_el.content = value.to_s
            end
          end
        end
      end

      # Returns what it says, the SFA class of the resource
      #
      def sfa_class()
        self.class.sfa_class()
      end

      # Returns the component id of this resource based on its URN
      # or creates a new one based on its name
      #
      def component_id
        if self.urn
          return GURN.create(self.urn, { :model => self.class })
        else
          return GURN.create(self.name, { :model => self.class })
        end
      end

      # Returns the default component manager id.
      #
      def component_manager_id
        self.class.default_component_manager_id
      end

      def component_name
        self.name
      end

    end #InstanceMethods

  end #Base
end #OMF::SFA::Model
