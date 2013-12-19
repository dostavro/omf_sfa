require 'omf_rc'
require 'omf_common'
#require 'omf-sfa/am/am-xmpp/am_authorizer'
require 'omf-sfa/am/default_authorizer'
require 'omf-sfa/resource'
require 'pp'

module OmfRc::ResourceProxy::AMController
  include OmfRc::ResourceProxyDSL

  register_proxy :am_controller

  hook :before_ready do |resource|
    #logger.debug "creation opts #{resource.creation_opts}"
    @manager = resource.creation_opts[:manager]
    @authorizer = resource.creation_opts[:authorizer]
  end

  request :resources do |resource|
    resources = @manager.find_all_resources_for_account(@manager._get_nil_account, @authorizer)
    OMF::SFA::Resource::OResource.resources_to_hash(resources)
  end

  request :components do |resource|
    components = @manager.find_all_components_for_account(@manager._get_nil_account, @authorizer)
    OMF::SFA::Resource::OResource.resources_to_hash(components)
  end

  request :nodes do |resource|
    nodes = @manager.find_all_components({:resource_type => "node"}, @authorizer)
    res = OMF::SFA::Resource::OResource.resources_to_hash(nodes, {max_levels: 3})
    res
  end

  request :leases do |resource|
    leases = @manager.find_all_leases(@authorizer)

    #this does not work because resources_to_hash and to_hash methods only works for
    #oproperties and account is not an oprop in lease so we need to add it
    res = OMF::SFA::Resource::OResource.resources_to_hash(leases)
    leases.each_with_index do |l, i=0|
      res[:resources][i][:resource][:account] = l.account.to_hash
    end
    res
  end

  request :slices do |resource|
    accounts = @manager.find_all_accounts(@authorizer)
    OMF::SFA::Resource::OResource.resources_to_hash(accounts)
  end


  configure :resource do |resource, value|
    puts "CONFIGURE #{value}"
  end


  def handle_create_message(message, obj, response)
    #puts "Create #{message.inspect}## #{obj.inspect}## #{response.inspect}"
    @manager = obj.creation_opts[:manager]

    opts = message.properties
    new_props = opts.reject { |k| [:type, :uid, :hrn, :property, :instrument].include?(k.to_sym) }
    puts "Message rtype #{message.rtype}"
    puts "Message new properties #{new_props.to_hash}"

    type = message.rtype.camelize
    new_res = create_resource(type, new_props)

    puts "NEW RES #{new_res.inspect}"
    new_res.to_hash.each do |key, value|
      response[key] = value
    end
    self.inform(:creation_ok, response)
  end

  private

  def create_resource(type, props)
    puts "Creating resource of type '#{type}' with properties '#{props}'"
    res = eval("OMF::SFA::Resource::#{type}").create(props)
    @manager.manage_resource(res)
  end


  #def handle_release_message(message, obj, response)
  #  puts "I'm not releasing anything"
  #end
end


module OMF::SFA::AM::XMPP

  class AMController
    include OMF::Common::Loggable


    def initialize(opts)
      @manager = opts[:manager]
      @authorizer = create_authorizer

      EM.next_tick do
        OmfCommon.comm.on_connected do |comm|
          auth = opts[:xmpp][:auth]

          entity_cert = File.expand_path(auth[:entity_cert])
          entity_key = File.expand_path(auth[:entity_key])
          @cert = OmfCommon::Auth::Certificate.create_from_x509(File.read(entity_cert), File.read(entity_key))
          OmfCommon::Auth::CertificateStore.instance.register(@cert, OmfCommon.comm.local_topic.address)

          trusted_roots = File.expand_path(auth[:root_cert_dir])
          OmfCommon::Auth::CertificateStore.instance.register_default_certs(trusted_roots)

          OmfRc::ResourceFactory.create(:am_controller, {uid: 'am_controller', certificate: @cert}, {manager: @manager, authorizer: @authorizer})
          puts "AM Resource Controller ready."
        end
      end

    end

    # This is temporary until we use an xmpp authorizer
    def create_authorizer
      auth = {}
      [
        # ACCOUNT
        :can_create_account?,
        :can_view_account?,
        :can_renew_account?,
        :can_close_account?,
        # RESOURCE
        :can_create_resource?,
        :can_view_resource?,
        :can_release_resource?,
        # LEASE
        :can_create_lease?,
        :can_view_lease?,
        :can_modify_lease?,
        :can_release_lease?,
      ].each do |m| auth[m] = true end
      OMF::SFA::AM::DefaultAuthorizer.new(auth)
    end

  end # AMController
end # module

