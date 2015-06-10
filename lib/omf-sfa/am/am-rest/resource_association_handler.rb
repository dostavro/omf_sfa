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

      target_resources = []
      if body.kind_of? Array
        body.each do |r|
          desc = {}
          desc[:uuid] = r[:uuid]
          raise OMF::SFA::AM::Rest::BadRequestException.new "uuid in body is mandatory." if desc[:uuid].nil?
          target_resources << @am_manager.find_resource(desc, target_type.singularize.camelize, authorizer)
        end
      else
        desc = {}
        desc[:uuid] = body[:uuid]
        raise OMF::SFA::AM::Rest::BadRequestException.new "uuid in body is mandatory." if desc[:uuid].nil?
        target_resources << @am_manager.find_resource(desc, target_type.singularize.camelize, authorizer)
      end
      
      # in those casses we need to use the manager and not the relation between them
      if source_type == 'Lease' && (target_type == 'nodes' || target_type == "channels") 
        scheduler = @am_manager.get_scheduler
        ac_id = source_resource.account.id
        target_resources.each do |target_resource|
          c = scheduler.create_child_resource({uuid: target_resource[:uuid], account_id: ac_id}, target_resource[:type].to_s.split('::').last)
          scheduler.lease_component(source_resource, c)
        end
      else
        if source_resource.class.method_defined?("add_#{target_type.singularize}")
          target_resources.each do |target_resource|
            raise OMF::SFA::AM::Rest::BadRequestException.new "resources are already associated." if source_resource.send(target_type).include?(target_resource)
            source_resource.send("add_#{target_type.singularize}", target_resource)
          end
        elsif source_resource.class.method_defined?("#{target_type.singularize}=")
          raise OMF::SFA::AM::Rest::BadRequestException.new "cannot associate many resources in a one-to-one relationship between '#{source_type}' and '#{target_type}'." if target_resources.size > 1 
          source_resource.send("#{target_type.singularize}=", target_resources.first)
        else
          raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid URL."
        end
      end

      if @special_cases.include?([source_type.pluralize.downcase, target_type.pluralize.downcase])
        self.send("add_#{target_type.pluralize.downcase}_to_#{source_type.pluralize.downcase}", target_resources, source_resource)
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

      target_resources = []
      if body.kind_of? Array
        body.each do |r|
          desc = {}
          desc[:uuid] = r[:uuid]
          raise OMF::SFA::AM::Rest::BadRequestException.new "uuid in body is mandatory." if desc[:uuid].nil?
          target_resources << @am_manager.find_resource(desc, target_type.singularize.camelize, authorizer)
        end
      else
        desc = {}
        desc[:uuid] = body[:uuid]
        raise OMF::SFA::AM::Rest::BadRequestException.new "uuid in body is mandatory." if desc[:uuid].nil?
        target_resources << @am_manager.find_resource(desc, target_type.singularize.camelize, authorizer)
      end

       # in this casses we need to use the manager and not the relation between them
      if source_type == 'Lease' && (target_type == 'nodes' || target_type == "channels") 
        scheduler = @am_manager.get_scheduler
        lease = source_resource
        target_resources.each do |comp|
          if comp.account.id == scheduler.get_nil_account.id # comp is a parent resource
            debug "remove parent resource association from lease."
            lease.components.each do |lcomp|
              if !lcomp.parent.nil? && lcomp.parent.id == comp.id
                @am_manager.release_resource(lcomp, authorizer) # release child resoure
                lease.remove_component(comp) # remove parent resource from lease
                lease.reload
                if lease.components.empty?
                  @am_manager.release_lease(lease, authorizer)
                end
              end
            end
          else # comp is a child resource
            debug "remove child resource association from lease."
            lease.remove_component(comp.parent)
            @am_manager.release_resource(comp, authorizer)
            if lease.components.empty?
              @am_manager.release_lease(lease, authorizer)
            end
          end
        end
      else
        if source_resource.class.method_defined?("remove_#{target_type.singularize}")
          target_resources.each do |target_resource|
            source_resource.send("remove_#{target_type.singularize}", target_resource.id)
          end
        elsif source_resource.class.method_defined?("#{target_type.singularize}=")
          raise OMF::SFA::AM::Rest::BadRequestException.new "cannot associate many resources in a one-to-one relationship between '#{source_type}' and '#{target_type}'." if target_resources.size > 1 
          source_resource.send("#{target_type.singularize}=", nil)
        else
          raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid URL."
        end
      end

      if @special_cases.include?([source_type.pluralize.downcase, target_type.pluralize.downcase])
        self.send("delete_#{target_type.pluralize.downcase}_from_#{source_type.pluralize.downcase}", target_resources, source_resource)
      end
      show_resource(source_resource, opts)
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
      init_special_cases()
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
      #TODO some manipulation on special case target types. Like the one in the resourceHandler's parse_uri method
      begin
        eval("OMF::SFA::Model::#{opts[:target_resource_uri].singularize.camelize}").class
      rescue NameError => ex
        raise OMF::SFA::AM::Rest::UnknownResourceException.new "Unknown resource type '#{target_type}'."
      end
      opts[:target_resource_uri] = target_type
      
      [source_type, source_uuid, target_type, params]
    end

    #######################################################################
    #     Special cases                                                   #
    #######################################################################
    # For every special case you need to do the following:                #
    # 1. initialize the special case in the init_special_cases function   #
    # bellow.                                                             #
    # 2. add two methods like the ones bellow that refer to [users, keys] #
    # special case and handle the special case there.                     #
    #######################################################################

    def init_special_cases
      @special_cases = [['users','keys'],['users','accounts']]
    end

    # this will call configure_keys of am_liaison and for every slice of 
    # the user it will add all the keys related to that slice (for every slice all
    # related users' ssh_keys)
    def add_keys_to_users(key, user)
      debug "add_keys_to_users: #{key.inspect} - #{user.inspect}"
      user.accounts.each do |ac|
        puts "-- #{ac.inspect}"
        keys = []
        ac.users.each do |u|
          u.keys.each do |k|
            keys << k unless keys.include? k
          end
        end

        @am_manager.liaison.configure_keys(keys, ac)
      end
    end

    # this will call configure_keys of am_liaison and for every slice of 
    # the user it will add all the keys related to that slice (for every slice all
    # related users' ssh_keys), because the key was just deleted it will prcticly delete 
    # the key from the slice.
    def delete_keys_from_users(key, user)
      debug "add_keys_to_users: #{key.inspect} - #{user.inspect}"
      user.accounts.each do |ac|
        puts "-- #{ac.inspect}"
        keys = []
        ac.users.each do |u|
          u.keys.each do |k|
            keys << k unless keys.include? k
          end
        end

        @am_manager.liaison.configure_keys(keys, ac)
      end
    end

    # this will configure_keys of am_liaison for all the slices in accounts arguement
    # and will add all the keys related to the each account
    def add_accounts_to_users(accounts, user)
      debug "add_accounts_to_users: #{accounts.inspect} - #{user.inspect}"
      accounts.each do |ac|
        keys = []
        ac.users.each do |u|
          u.keys.each do |k|
            keys << k unless keys.include? k
          end
        end

        @am_manager.liaison.configure_keys(keys, ac)
      end
    end

    # this will configure_keys of am_liaison for all the slices in accounts arguement
    # and will add all the keys related to the each account. Because the accounts user
    # was deleted with this call, it will practicly just delete the specific user keys 
    # from all the accounts 
    def delete_accounts_from_users(accounts, user)
      debug "delete_accounts_from_users:  #{accounts.inspect} - #{user.inspect}"
      accounts.each do |ac|
        keys = []
        ac.users.each do |u|
          next if u == user # this shouldn't happen anyway.
          u.keys.each do |k|
            keys << k unless keys.include? k
          end
        end

        @am_manager.liaison.configure_keys(keys, ac)
      end
    end
  end # ResourceHandler
end # module
