require 'omf-sfa/am/am-rest/resource_handler'
require 'omf-sfa/am/am_manager'

module OMF::SFA::AM::Rest

  # Handles an resource membderships
  #
  class ResourceAssociationHandler < ResourceHandler

    # List a resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the requested resource.
    def on_get(resource_uri, opts)
      debug "on_get: #{resource_uri}"
      source_type, source_uuid, target_type, params = parse_uri(resource_uri, opts)
      desc = {}
      desc[:uuid] = source_uuid
      authorizer = opts[:req].session[:authorizer]
      source_resource = @am_manager.find_resource(desc, source_type, authorizer)
      # target_type = target_type.downcase.pluralize
      if source_resource.class.method_defined?(target_type)
        resource = source_resource.send(target_type)
        return show_resource(resource, opts)
      else
        raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid URL."
      end
    end

    # Update an existing resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the updated resource.
    def on_put(resource_uri, opts)
      debug "on_put: #{resource_uri}"
      source_type, source_uuid, target_type, params = parse_uri(resource_uri, opts)
      desc = {}
      desc[:uuid] = source_uuid
      authorizer = opts[:req].session[:authorizer]
      source_resource = @am_manager.find_resource(desc, source_type, authorizer)
      raise InsufficientPrivilegesException unless authorizer.can_modify_resource?(source_resource, source_type)
      body, format = parse_body(opts)
      desc = {}
      desc[:uuid] = body[:uuid]
      raise OMF::SFA::AM::Rest::BadRequestException.new "uuid in body is mandatory." if desc[:uuid].nil?
      target_resource = @am_manager.find_resource(desc, target_type.singularize.camelize, authorizer)
      
      if source_resource.class.method_defined?("add_#{target_type.singularize}")
        source_resource.send("add_#{target_type.singularize}", target_resource)
        show_resource(source_resource, opts)
      elsif source_resource.class.method_defined?("#{target_type.singularize}=")
        source_resource.send("#{target_type.singularize}=", target_resource)
        show_resource(source_resource, opts)
      else
        raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid URL."
      end
      show_resource(source_resource, opts)
    end

    # Deletes an existing resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the created resource.
    def on_delete(resource_uri, opts)
      debug "on_delete: #{resource_uri}"
      source_type, source_uuid, target_type, params = parse_uri(resource_uri, opts)
      desc = {}
      desc[:uuid] = source_uuid
      authorizer = opts[:req].session[:authorizer]
      source_resource = @am_manager.find_resource(desc, source_type, authorizer)
      raise InsufficientPrivilegesException unless authorizer.can_modify_resource?(source_resource, source_type)
      body, format = parse_body(opts)
      desc = {}
      desc[:uuid] = body[:uuid]
      raise OMF::SFA::AM::Rest::BadRequestException.new "uuid in body is mandatory." if desc[:uuid].nil?
      target_resource = @am_manager.find_resource(desc, target_type.singularize.camelize, authorizer)

      if source_resource.class.method_defined?("remove_#{target_type.singularize}")
        source_resource.send("remove_#{target_type.singularize}", target_resource.id)
        show_resource(source_resource, opts)
      elsif source_resource.class.method_defined?("#{target_type.singularize}=")
        source_resource.send("#{target_type.singularize}=", nil)
        show_resource(source_resource, opts)
      else
        raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid URL."
      end
    end

    # Create a new resource
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the created resource.
    def on_post(resource_uri, opts)
      debug "on_post: #{resource_uri}"
      raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid URL."
    end

    protected
    def parse_uri(resource_uri, opts)
      params = opts[:req].params.symbolize_keys!
      params.delete("account")

      source_type = opts[:source_resource_uri].singularize.camelize
      begin
        eval("OMF::SFA::Model::#{source_type}").class
      rescue NameError => ex
        raise OMF::SFA::AM::Rest::UnknownResourceException.new "Unknown resource type '#{source_type}'."
      end

      source_uuid = opts[:source_resource_uuid]

      target_type = opts[:target_resource_uri]
      begin
        eval("OMF::SFA::Model::#{opts[:target_resource_uri].singularize.camelize}").class
      rescue NameError => ex
        raise OMF::SFA::AM::Rest::UnknownResourceException.new "Unknown resource type '#{target_type}'."
      end
      opts[:target_resource_uri] = target_type
      
      [source_type, source_uuid, target_type, params]
    end
  end # ResourceHandler
end # module
