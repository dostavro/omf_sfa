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
    nodes = @manager.find_all_components({:type => "OMF::SFA::Resource::Node"}, @authorizer)
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
    puts "Create #{message.inspect}## #{obj.inspect}## #{response.inspect}"
    @manager = obj.creation_opts[:manager]
    @authorizer = obj.creation_opts[:authorizer]
    @scheduler = @manager.get_scheduler

    opts = message.properties
    puts "opts #{opts.inspect}"
    new_props = opts.reject { |k| [:type, :uid, :hrn, :property, :instrument].include?(k.to_sym) }
    type = message.rtype.camelize

    # new_props.each do |key, value|
    #   puts "checking prop: '#{key}': '#{value}': '#{type}'"
    #   if value.kind_of? Array
    #     value.each_with_index do |v, i|
    #       if v.kind_of? Hash
    #         puts "Array: #{v.inspect}"
    #         model = eval("OMF::SFA::Resource::#{type}.#{key}").model
    #         new_props[key][i] = (k = eval("#{model}").first(v)) ? k : v
    #       end
    #     end
    #   elsif value.kind_of? Hash
    #       puts "Hash: #{value.inspect}"
    #       model = eval("OMF::SFA::Resource::#{type}.#{key}").model
    #       new_props[key] = (k = eval("#{model}").first(value)) ? k : value
    #   end
    # end

    puts "Message rtype #{message.rtype}"
    puts "Message new properties #{new_props.class} #{new_props.inspect}"

    
    new_res = create_resource(type, new_props)

    puts "NEW RES #{new_res.inspect}"
    new_res.to_hash.each do |key, value|
      response[key] = value
    end
    self.inform(:creation_ok, response)
  end

  private

  def create_resource(type, props)
    puts "Creating resource of type '#{type}' with properties '#{props.inspect}' @ '#{@scheduler.inspect}'"
    if type == "Lease" #Lease is a unigue case, needs special treatment
      #res = eval("OMF::SFA::Resource::#{type}").create(props)
      
      res_descr = {name: props[:name]}
      if comps = props[:components]
        #props.reject!{ |k| k == :components}
        props.tap { |hs| hs.delete(:components) }
      end
      
      #TODO when authorization is done remove the next line in order to change what authorizer does with his account
      @authorizer.account = props[:account]

      l = @scheduler.create_resource(res_descr, type, props, @authorizer)

      comps.each_with_index do |comp, i|
        if comp[:type].nil?
          comp[:type] = comp.model.to_s.split("::").last
        end
        c = @scheduler.create_resource(comp, comp[:type], {}, @authorizer)
        @scheduler.lease_component(l, c)
      end
      l
    else
      res = eval("OMF::SFA::Resource::#{type}").create(props)
      @manager.manage_resource(res.cmc) if res.respond_to?(:cmc) && !res.cmc.nil?
      @manager.manage_resource(res)
    end
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
          # if entity cert contains the private key just add the entity cert else add the entity_key too
          pem_file = File.open(entity_cert).lines.any? { |line| line.chomp == '-----BEGIN RSA PRIVATE KEY-----'} ? File.read(entity_cert) : "#{File.read(entity_cert)}#{File.read(entity_key)}"
          @cert = OmfCommon::Auth::Certificate.create_from_pem(pem_file)
          @cert.resource_id = OmfCommon.comm.local_topic.address
          OmfCommon::Auth::CertificateStore.instance.register(@cert)

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

