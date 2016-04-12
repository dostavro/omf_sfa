require 'omf-sfa/am/am-rest/rest_handler'
require 'omf-sfa/am/am_manager'
require 'uuid'

DEFAULT_SAVE_IMAGE_NAME = '/tmp/image.nbz'

module OMF::SFA::AM::Rest

  # Handles an individual resource
  #
  class ActionsHandler < RestHandler

    # Return the handler responsible for requests to +path+.
    # The default is 'self', but override if someone else
    # should take care of it
    #
    def find_handler(path, opts)
      opts[:resource_uri] = path.shift
      @liaison = @am_manager.liaison
      self
    end

    # Actions that don't change the status of resources
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the requested resource.
    def on_get(resource_uri, opts)
      debug "on_get: #{resource_uri}"
      action, params = parse_uri(resource_uri, opts)
      authorizer = opts[:req].session[:authorizer]

      raise OMF::SFA::AM::Rest::UnknownResourceException.new "Action '#{resource_uri}' is not supported by method GET." unless action == 'status'

      response = {}
      if params[:nodes]
        params[:nodes].each do |node|
          response[node.to_sym] = @liaison.get_node_status(node)
        end
      elsif params[:job_ids]
        params[:job_ids].each do |job_id|
          response[job_id.to_sym] = @liaison.get_job_status(job_id)
        end
      end

      ['application/json', "#{JSON.pretty_generate({resp: response}, :for_rest => true)}\n"]
    end

    # Actions that change the status of resources
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the updated resource.
    def on_put(resource_uri, opts)
      debug "on_put: #{resource_uri}"
      action, params = parse_uri(resource_uri, opts)
      action = 'reset' if action == 'reboot' || action == "restart" 
      body, format = parse_body(opts)
      authorizer = opts[:req].session[:authorizer]
      account = authorizer.account
      debug "action: #{action.inspect} params: #{params.inspect} format: #{format.inspect} account_id: #{account.id} body: #{body.inspect}"

      if account.id != @am_manager._get_nil_account.id
        error "non root account issued action: '#{action}'"
        raise OMF::SFA::AM::Rest::NotAuthorizedException.new "Not Authorized!!"
      end

      response = {}
      case action
      when 'on' , 'off' , 'reset'
        body[:nodes].each do |node|
          response[node.to_sym] = @liaison.change_node_status(node, action)
        end
      when 'save'
        node = body[:node]
        image_name = body[:image_name] || DEFAULT_SAVE_IMAGE_NAME
        response[node.to_sym] = @liaison.save_node_image(node, image_name)
       when 'load'
        nodes = []
        body[:nodes].each do |node|
          nodes << OMF::SFA::Model::Node.first(name: node, account_id: 2)
        end
        sliver_type = OMF::SFA::Model::SliverType.first(name: body[:sliver_type])
        response = @liaison.provision(nodes, sliver_type, authorizer)
      else
        raise OMF::SFA::AM::Rest::UnknownResourceException.new "Action '#{action}' is not supported by method PUT."
      end
      
      ['application/json', "#{JSON.pretty_generate({resp: response}, :for_rest => true)}\n"]
    end

    # Not supported by this handler
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the created resource.
    def on_post(resource_uri, opts)
      debug "on_post: #{resource_uri}"
      
      raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid URL."
    end

    # Not supported by this handler
    # 
    # @param [String] request URI
    # @param [Hash] options of the request
    # @return [String] Description of the created resource.
    def on_delete(resource_uri, opts)
      debug "on_delete: #{resource_uri}"
      
      raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid URL."
    end

    protected

    def parse_uri(resource_uri, opts)
      params = opts[:req].params.symbolize_keys!

      case resource_uri
      when "status"
        type = "status"
        params[:nodes] = params[:nodes].split(',') if params[:nodes]
        params[:job_ids] = params[:job_ids].split(',') if params[:job_ids]
      when "on"
        type = "on"
      when "off"
        type = "off"
      when "reset"
        type = "reset"
      when "load"
        type = "load"
      when "save"
        type = "save"
      else
        raise OMF::SFA::AM::Rest::UnknownResourceException.new "Action '#{resource_uri}' not supported"
      end
      [type, params]
    end
  end # ResourceHandler
end # module
