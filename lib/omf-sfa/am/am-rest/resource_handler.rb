require 'omf-sfa/resource'
require 'omf-sfa/am/am-rest/rest_handler'
require 'omf-sfa/am/am_manager'

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
      authenticator = opts[:req].session[:authorizer]
      raise OMF::SFA::AM::Rest::BadRequestException.new "path '/mapper' is only available for POST requests." if opts[:req].env["REQUEST_PATH"] == '/mapper'
      unless resource_uri.empty?
        resource_type, resource_params = parse_uri(resource_uri, opts)
        descr = {}
        # descr.merge!({type: "OMF::SFA::Resource::#{resource_type}"}) unless resource_type.nil?  
        descr.merge!(resource_params) unless resource_params.empty?
        opts[:path] = opts[:req].path.split('/')[0 .. -2].join('/')
        if descr[:name].nil? && descr[:uuid].nil?
          # descr[:account] = @am_manager.get_scheduler.get_nil_account unless resource_uri == 'leases'
          descr[:account_id] = @am_manager.get_scheduler.get_nil_account if (resource_uri == 'nodes' || resource_uri == 'channels')
          if resource_uri == 'accounts'
            raise NotAuthorizedException, "User not found, please attach user certificates for this request." if authenticator.user.nil?
            resource = @am_manager.find_all_accounts(authenticator)
          elsif resource_uri == 'leases'
            resource =  @am_manager.find_all_leases(nil, ["pending", "accepted", "active"], authenticator)
          else
            resource =  @am_manager.find_all_resources(descr, authenticator)
          end
        else
          # descr[:account] = @am_manager.get_scheduler.get_nil_account unless resource_uri == 'leases'
          descr[:account_id] = @am_manager.get_scheduler.get_nil_account if (resource_uri == 'nodes' || resource_uri == 'channels')
          resource = @am_manager.find_resource(descr, authenticator)
        end
      else
        body, format = parse_body(opts)
        debug "body: #{body.inspect}, format: #{format.inspect}"
        unless body.empty?
          resp = resolve_unbound_request(body, format, authenticator)
          return resp
        else
          resource = @am_manager.find_all_resources_for_account(opts[:account], authenticator)
        end
      end
      raise UnknownResourceException, "No resources matching the request." if resource.empty?
      show_resource(resource, opts)
    end

    # Update an existing resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the updated resource.
    def on_put(resource_uri, opts)
      debug "on_put: #{resource_uri}"
      raise OMF::SFA::AM::Rest::BadRequestException.new "path '/mapper' is only available for POST requests." if opts[:req].env["REQUEST_PATH"] == '/mapper'
      resource = update_resource(resource_uri, true, opts)
      show_resource(resource, opts)
    end

    # Create a new resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the created resource.
    def on_post(resource_uri, opts)
      debug "on_post: #{resource_uri} - #{opts[:req].env["REQUEST_PATH"]}"
      if opts[:req].env["REQUEST_PATH"] == '/mapper' || opts[:req].env["REQUEST_PATH"] == '/mapper/'
        debug "Unbound request detected."
        body, format = parse_body(opts)
        authenticator = opts[:req].session[:authorizer]
        resp = resolve_unbound_request(body, format, authenticator)
        return resp
      end
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
      raise OMF::SFA::AM::Rest::BadRequestException.new "path '/mapper' is only available for POST requests." if opts[:req].env["REQUEST_PATH"] == '/mapper'
      delete_resource(resource_uri, opts)
      show_resource(nil, opts)
    end


    # Update resource(s) referred to by +resource_uri+. If +clean_state+ is
    # true, reset any other state to it's default.
    #
    def update_resource(resource_uri, clean_state, opts)
      body, format = parse_body(opts)
      resource_type, resource_params = parse_uri(resource_uri, opts)
      authenticator = opts[:req].session[:authorizer]
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
      authenticator = opts[:req].session[:authorizer]
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
      debug "resource_to_json: resource: #{resource.inspect}, path: #{path}"
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
          # rh = resource.to_hash(already_described, opts.merge(:href_prefix => prefix, max_levels: 3))
          rh = JSON.parse(resource.to_json(:include=>{:interfaces => {}, :leases => {}, :account => {:only => :name}, :cmc => {}, :cpus => {}}))

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
      params.delete("account")

      return ['mapper', params] if opts[:req].env["REQUEST_PATH"] == '/mapper'

      case resource_uri
      when "cmc"
        type = "ChasisManagerCard"
      when "wimax"
        type = "WimaxBase"
      when "lte"
        type = "LteBase"
      when "openflow"
        type = "OpenflowSwitch"
      else
        type = resource_uri.singularize.camelize
        begin
          eval("OMF::SFA::Model::#{type}").class
        rescue NameError => ex
          raise OMF::SFA::AM::Rest::UnknownResourceException.new "Unknown resource type '#{resource_uri}'."
        end
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
      debug "create_new_resource: resource_descr: #{resource_descr}, type_to_create: #{type_to_create}"
      authorizer.can_create_resource?(resource_descr, type_to_create)
      if resource_descr.kind_of? Array
        descr = []
        resource_descr.each do |res|
          res_descr = {}
          res_descr.merge!({uuid: res[:uuid]}) if res.has_key?(:uuid)
          res_descr.merge!({name: res[:name]}) if res.has_key?(:name)
          descr << res_descr unless eval("OMF::SFA::Model::#{type_to_create}").first(res_descr)
        end
        raise OMF::SFA::AM::Rest::BadRequestException.new "No resources described in description #{resource_descr} is valid. Maybe all the resources alreadt=y exist." if descr.empty?
      elsif resource_descr.kind_of? Hash
        descr = {}
        descr.merge!({uuid: resource_descr[:uuid]}) if resource_descr.has_key?(:uuid)
        descr.merge!({name: resource_descr[:name]}) if resource_descr.has_key?(:name)
      
        if descr.empty?
          raise OMF::SFA::AM::Rest::BadRequestException.new "Resource description is '#{resource_descr}'."
        else
          raise OMF::SFA::AM::Rest::BadRequestException.new "Resource with descr '#{descr} already exists'." if eval("OMF::SFA::Model::#{type_to_create}").first(descr)
        end
      end

      if type_to_create == "Lease" #Lease is a unigue case, needs special treatment
        resource_descr.each do |key, value|
          # debug "checking prop: '#{key}': '#{value}': '#{type_to_create}'"
          if value.kind_of? Array # this will be components
            value.each_with_index do |v, i|
              if v.kind_of? Hash
                # debug "Array: #{v.inspect}"
                model = eval("OMF::SFA::Resource::#{type_to_create}.#{key}").model
                if k = eval("#{model}").first(v)
                  resource_descr[key][i] = k 
                else
                  resource_descr[key].delete_at(i)
                  i -= 1 # just ignore the resource
                end
              end
            end
          elsif value.kind_of? Hash #this will be account
            # debug "Hash: #{value.inspect}"
            model = eval("OMF::SFA::Resource::#{type_to_create}.#{key}").model
            if k = eval("#{model}").first(value)
              resource_descr[key] = k 
            else
              resource_descr.delete!(key)
            end
          end
        end

        res_descr = {name: resource_descr[:name]}
        if comps = resource_descr[:components]
          resource_descr.tap { |hs| hs.delete(:components) }
        end
        @scheduler = @am_manager.get_scheduler
        #TODO when authorization is done remove the next line in order to change what authorizer does with his account
        authorizer.account = resource_descr[:account]
        resource = @scheduler.create_resource(res_descr, type_to_create, resource_descr, authorizer)

        comps.each_with_index do |comp, i|
          if comp[:type].nil?
            comp[:type] = comp.model.to_s.split("::").last
          end
          c = @scheduler.create_resource({uuid: comp.uuid}, comp[:type], {}, authorizer)
          @scheduler.lease_component(resource, c)
        end
      else
        if resource_descr.kind_of? Array
          resource = []
          resource_descr.each do |res_desc|
            # res_desc = parse_resource_description(res_desc, type_to_create)
            resource << eval("OMF::SFA::Model::#{type_to_create}").create(res_desc)
            @am_manager.manage_resource(resource.last) if resource.last.account.nil?
          end
        elsif resource_descr.kind_of? Hash
          # resource_descr = parse_resource_description(resource_descr, type_to_create)
          resource = eval("OMF::SFA::Model::#{type_to_create}").create(resource_descr)
          @am_manager.manage_resource(resource) if resource.account.nil?
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
    def update_a_resource(resource_descr, type_to_create, authorizer)
      authorizer.can_modify_resource?(resource_descr, type_to_create)
      descr = {}
      descr.merge!({uuid: resource_descr[:uuid]}) if resource_descr.has_key?(:uuid)
      descr.merge!({name: resource_descr[:name]}) if descr[:uuid].nil? && resource_descr.has_key?(:name)
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

    # Release a resource
    #
    # @param [Hash] Describing properties of the requested resource
    # @param [String] Type to create
    # @param [Authorizer] Defines context for authorization decisions
    # @return [OResource] The resource created
    # @raise [UnknownResourceException] if no resource can be created
    #
    def release_resource(resource_descr, type_to_create, authorizer)
      if type_to_create == "Lease" #Lease is a unigue case, needs special treatment
        if resource = OMF::SFA::Resource::Lease.first(resource_descr)
          @am_manager.release_lease(resource, authorizer)
        else
          raise OMF::SFA::AM::Rest::UnknownResourceException.new "Unknown Lease with descr'#{resource_descr}'."
        end
      else
        authorizer.can_release_resource?(resource_descr)
        if resource = eval("OMF::SFA::Resource::#{type_to_create}").first(resource_descr)
          resource.destroy
        else
          raise OMF::SFA::AM::Rest::UnknownResourceException.new "Unknown resource with descr'#{resource_descr}'."
        end
      end
      resource
    end

    def resolve_unbound_request(body, format, authenticator)
      if format == :json
        begin
          resource = @am_manager.get_scheduler.resolve_query(body, @am_manager, authenticator)
          debug "response: #{resource}, #{resource.class}"
          return ['application/json', JSON.pretty_generate({:resource_response => resource}, :for_rest => true)]
        rescue OMF::SFA::AM::UnavailableResourceException
          raise UnknownResourceException, "There are no available resources matching the request."
        rescue MappingSubmodule::UnknownTypeException
          raise BadRequestException, "Missing the mandatory parameter 'type' from one of the requested resources."
        end
      else
        raise UnsupportedBodyFormatException, "Format '#{format}' is not supported, please try json."
      end
    end

    # Before create a new resource, parse the resource description and alternate existing resources.
    #
    # @param [Hash] Resource Description
    # @return [Hash] New Resource Description
    # @raise [UnknownResourceException] if no resource can be created
    #
    def parse_resource_description(resource_descr, type_to_create)
      resource_descr.each do |key, value|
        debug "checking prop: '#{key}': '#{value}': '#{type_to_create}'"
        if value.kind_of? Array
          value.each_with_index do |v, i|
            if v.kind_of? Hash
              # debug "Array: #{v.inspect}"
              begin
                k = eval("OMF::SFA::Resource::#{key.to_s.singularize.capitalize}").first(v)
                raise NameError if k.nil?
                resource_descr[key][i] = k
              rescue NameError => nex
                model = eval("OMF::SFA::Resource::#{type_to_create}.get_oprops[key][:__type__]")
                resource_descr[key][i] = (k = eval("OMF::SFA::Resource::#{model}").first(v)) ? k : v
              end
            end
          end
        elsif value.kind_of? Hash
          debug "Hash: #{key.inspect}: #{value.inspect}"
          begin
            k = eval("OMF::SFA::Resource::#{key.to_s.singularize.capitalize}").first(value)
            raise NameError if k.nil?
            resource_descr[key] = k
          rescue NameError => nex
            model = eval("OMF::SFA::Resource::#{type_to_create}.get_oprops[key][:__type__]")
            resource_descr[key] = (k = eval("OMF::SFA::Resource::#{model}").first(value)) ? k : value
          end
        end
      end
      resource_descr
    end

  end # ResourceHandler
end # module
