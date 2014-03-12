
require 'omf-sfa/am/am-rest/rest_handler'

module OMF::SFA::AM::Rest

  # Handles an individual resource
  #
  class ResourceHandler < RestHandler

    # Return the handler responsible for requests to +path+.
    # The default is 'self', but override if someone else
    # should take care of it
    #
    def find_handler(path, opts)
      #opts[:account] = @am_manager.get_default_account
      opts[:resource_uri] = path.join('/')
      debug "find_handler: path: '#{path}' opts: '#{opts.inspect}'"
      self
    end

    # List a resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the requested resource.
    def on_get(resource_uri, opts)
      debug "on_get: #{resource_uri}"
      authenticator = Thread.current["authenticator"]
      unless resource_uri.empty?
        resource_type, resource_params = parse_uri(resource_uri, opts)
        descr = {}
        descr.merge!({type: "OMF::SFA::Resource::#{resource_type}"}) unless resource_type.nil?  
        descr.merge!(resource_params) unless resource_params.empty?
        opts[:path] = opts[:req].path.split('/')[0 .. -2].join('/')
        if descr[:name].nil? && descr[:uuid].nil?
          resource = @am_manager.find_all_resources(descr, authenticator)
        else
          resource = @am_manager.find_resource(descr, authenticator)
        end
      else
        resource = @am_manager.find_all_resources_for_account(opts[:account], authenticator)
      end
      show_resource(resource, opts)
    end

    # Update an existing resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the updated resource.
    def on_put(resource_uri, opts)
      debug "on_put: #{resource_uri}"
      resource = update_resource(resource_uri, true, opts)
      show_resource(resource, opts)
    end

    # Create a new resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the created resource.
    def on_post(resource_uri, opts)
      debug "on_post: #{resource_uri}"
      resource = update_resource(resource_uri, false, opts)
      show_resource(resource, opts)
    end

    # Deletes an existing resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the created resource.
    def on_delete(resource_uri, opts)
      debug "on_delete: #{resource_uri}"
      delete_resource(resource_uri, opts)
      show_resource(nil, opts)
    end


    # Update resource(s) referred to by +resource_uri+. If +clean_state+ is
    # true, reset any other state to it's default.
    #
    def update_resource(resource_uri, clean_state, opts)
      body, format = parse_body(opts)
      resource_type, resource_params = parse_uri(resource_uri, opts)
      authenticator = Thread.current["authenticator"]
      case format
      # when :empty
        # # do nothing
      when :xml
        resource = @am_manager.update_resources_from_xml(body.root, clean_state, opts)
      when :json
        if clean_state
          resource = update_a_resource(body, resource_type, authenticator)
        else
          resource = create_new_resource(body, resource_type, authenticator)
        end
      else
        raise UnsupportedBodyFormatException.new(format)
      end
      resource
    end


    # This methods deletes components, or more broadly defined, removes them
    # from a slice.
    #
    # Currently, we simply transfer components to the +default_sliver+
    #
    def delete_resource(resource_uri, opts)
      body, format = parse_body(opts)
      resource_type, resource_params = parse_uri(resource_uri, opts)
      authenticator = Thread.current["authenticator"]
      release_resource(body, resource_type, authenticator)
    end

    # Update the state of +component+ according to inforamtion
    # in the http +req+.
    #
    #
    def update_component_xml(component, modifier_el, opts)
    end

    # Return the state of +component+
    #
    # +component+ - Component to display information about. !!! Can be nil - show only envelope
    #
    def show_resource(resource, opts)
      unless about = opts[:req].path
        throw "Missing 'path' declaration in request"
      end
      path = opts[:path] || about

      case opts[:format]
      when 'xml'
        show_resources_xml(resource, path, opts)
      else
        show_resources_json(resource, path, opts)
      end
    end

    def show_resources_xml(resource, path, opts)
      #debug "show_resources_xml: #{resource}"
      opts[:href_prefix] = path
      announcement = OMF::SFA::Resource::OComponent.sfa_advertisement_xml(resource, opts)
      ['text/xml', announcement.to_xml]
    end

    def show_resources_json(resources, path, opts)
      res = resources ? resource_to_json(resources, path, opts) : {response: "OK"}
      res[:about] = opts[:req].path

      ['application/json', JSON.pretty_generate({:resource_response => res}, :for_rest => true)]
    end

    def resource_to_json(resource, path, opts, already_described = {})
      debug "resource_to_json: resource: #{resource}, path: #{path}"
      if resource.kind_of? Enumerable
        res = []
        resource.each do |r|
          p = path
          res << resource_to_json(r, p, opts, already_described)[:resource]
        end
        res = {:resources => res}
      else
        #prefix = path.split('/')[0 .. -2].join('/') # + '/'
        prefix = path
        if resource.respond_to? :to_sfa_hashXXX
          debug "TO_SFA_HASH: #{resource}"
          res = {:resource => resource.to_sfa_hash(already_described, :href_prefix => prefix)}
        else
          rh = resource.to_hash(already_described, opts.merge(:href_prefix => prefix, max_levels: 3))
          # unless (account = resource.account) == @am_manager.get_default_account()
            # rh[:account] = {:uuid => account.uuid.to_s, :name => account.name}
          # end
          res = {:resource => rh}
        end
      end
      res
    end

    protected

    def parse_uri(resource_uri, opts)
      params = opts[:req].params

      case resource_uri
      when "nodes"
        type = "Node"
      when "channels"
        type = "Channel"
      when "leases"
        type = "Lease"
      when "cmc"
        type = "ChasisManagerCard"
      when "wimax"
        type = "WimaxBase"
      when "lte"
        type = "LteBase"
      when "openflow"
        type = "OpenflowSwitch"
      else
        raise OMF::SFA::AM::Rest::UnknownResourceException.new "Unknown resource type'#{resource_uri}'."
      end
      [type, params]
    end

    # Create a new resource
    #
    # @param [Hash] Describing properties of the requested resource
    # @param [String] Type to create
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] The resource created
    # @raise [UnknownResourceException] if no resource can be created
    #
    def create_new_resource(resource_descr, type_to_create, authorizer)
      authorizer.can_create_resource?(resource_descr, type_to_create)
      descr = {}
      descr.merge!({uuid: resource_descr[:uuid]}) if resource_descr.has_key?(:uuid)
      descr.merge!({name: resource_descr[:name]}) if resource_descr.has_key?(:name)
      if descr.empty?
        raise OMF::SFA::AM::Rest::BadRequestException.new "Resource description is '#{resource_descr}'."
      else
        raise OMF::SFA::AM::Rest::BadRequestException.new "Resource with descr '#{descr} already exists'." if eval("OMF::SFA::Resource::#{type_to_create}").first(descr)
      end
      resource = eval("OMF::SFA::Resource::#{type_to_create}").create(resource_descr)
      @am_manager.manage_resource(resource)
      resource
    end

    # Update a resource
    #
    # @param [Hash] Describing properties of the requested resource
    # @param [String] Type to create
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] The resource created
    # @raise [UnknownResourceException] if no resource can be created
    #
    def update_a_resource(resource_descr, type_to_create, authorizer)
      authorizer.can_modify_resource?(resource_descr, type_to_create)
      descr = {}
      descr.merge!({uuid: resource_descr[:uuid]}) if resource_descr.has_key?(:uuid)
      descr.merge!({name: resource_descr[:name]}) if resource_descr.has_key?(:name)
      unless descr.empty?
        if resource = eval("OMF::SFA::Resource::#{type_to_create}").first(descr)
          resource.update(resource_descr)
          @am_manager.manage_resource(resource)
        else
          raise OMF::SFA::AM::Rest::UnknownResourceException.new "Unknown resource with descr'#{resource_descr}'."
        end
      end
      resource
    end

    # Update a resource
    #
    # @param [Hash] Describing properties of the requested resource
    # @param [String] Type to create
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] The resource created
    # @raise [UnknownResourceException] if no resource can be created
    #
    def release_resource(resource_descr, type_to_create, authorizer)
      authorizer.can_release_resource?(resource_descr)
      if resource = eval("OMF::SFA::Resource::#{type_to_create}").first(resource_descr)
        resource.destroy
      else
        raise OMF::SFA::AM::Rest::UnknownResourceException.new "Unknown resource with descr'#{resource_descr}'."
      end
      resource
    end
  end # ResourceHandler
end # module
