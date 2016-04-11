require 'omf_common'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/default_am_liaison'
require "net/https"
require "uri"
require 'json'

DEFAULT_REST_END_POINT = {url: "https://localhost:4567", user: "root", token: "1234556789abcdefghij"}

module OMF::SFA::AM

  extend OMF::SFA::AM

  # This class implements the AM Liaison
  #
  class NitosAMLiaison < DefaultAMLiaison

    def initialize(opts)
      super
      @default_sliver_type = OMF::SFA::Model::SliverType.find(urn: @config[:provision][:default_sliver_type_urn])
      @rest_end_points = @config[:REST_end_points]
    end

    def create_account(account)
      debug "create_account: '#{account.inspect}'"

      OmfCommon.comm.subscribe('user_factory') do |user_rc|
        unless user_rc.error?

          user_rc.create(:user, hrn: 'newuser', username: account.name) do |reply_msg|
            if reply_msg.success?
              user = reply_msg.resource

              user.on_subscribed do
                user.on_message do |m|
                  if m.operation == :inform
                    if m.read_content("itype").eql?('STATUS')
                      if m.read_property("status_type") == 'APP_EVENT'
                        issuer = OmfCommon::Auth::CertificateStore.instance.cert_for(OmfCommon.comm.local_topic.address)
                        duration = account.valid_until.to_i - Time.now.utc.to_i
                        email = "#{account.name}@#{OMF::SFA::Resource::Constants.default_domain}"
                        pub_key = m.read_property('pub_key')
                        key = OpenSSL::PKey::RSA.new(pub_key)
                        user_id = account.uuid
                        geni_uri = "URI:urn:publicid:IDN+#{OMF::SFA::Resource::Constants.default_domain}+user+#{account.name}"

                        xname = [['C', 'US'], ['ST', 'CA'], ['O', 'ACME'], ['OU', 'Roadrunner']]
                        xname << ['CN', "#{user_id}/emailAddress=#{email}"]
                        subject = OpenSSL::X509::Name.new(xname)

                        addresses = []
                        addresses << "URI:uuid:#{user_id}"
                        addresses << geni_uri

                        user_cert = OmfCommon::Auth::Certificate._create_x509_cert(subject, key, nil, issuer, Time.now, duration, addresses)
                        user.configure(cert: user_cert[:cert].to_pem) do |reply|
                          if reply.success?
                            release_proxy(user_rc, user)
                          else
                            error "Configuration of the certificate failed - #{reply[:reason]}"
                          end
                        end
                      end
                    end
                  end
                end
              end
            else
              error ">>> Resource creation failed - #{reply_msg[:reason]}"
            end
          end
        else
          raise UnknownResourceException.new "Cannot find resource's pubsub topic: '#{user_rc.inspect}'"
        end
      end

      create_account_on_flowvisor(account)
    end


    def create_account_on_flowvisor(account)
      debug "create_account_on_flowvisor: '#{account.inspect}'"
      OmfCommon.comm.subscribe(:nitos_flowvisor) do |controller|
        controller.configure(flowvisor_connection: {host: "83.212.32.137", password: "fl0wv1s0r"}) do |ans|
          controller.create(:openflow_slice, {name: account.name, true_create: true}) do |reply_msg| 
            if reply_msg.success?
              slice = reply_msg.resource

              slice.on_subscribed do
                info ">>> Connected to newly created slice #{reply_msg[:res_id]} with name #{reply_msg[:name]}"
              end
            else
              error ">>> Flowvisor Slice creation failed - #{reply_msg[:reason]}"
            end
          end
        end
      end
    end

    def close_account(account)
      OmfCommon.comm.subscribe('user_factory') do |user_rc|
        unless user_rc.error?

          user_rc.configure(deluser: {username: account.name}) do |msg|
            if msg.success?
              info "Account: '#{account.inspect}' successfully deleted."
            else
              error "Account: '#{account.inspect}' couldn't deleted."
            end
          end

        else
          raise UnknownResourceException.new "Cannot find resource's pubsub topic: '#{user_rc.inspect}'"
        end
      end

      close_account_on_flowvisor(account)
    end

    def close_account_on_flowvisor(account)
      debug "close_account_on_flowvisor: '#{account.inspect}'"
      OmfCommon.comm.subscribe(:nitos_flowvisor) do |controller|
        controller.configure(delete_slice: {name: account.name}) do |reply_msg|
          info ">>> Released slice #{reply_msg[:res_id]}"
        end
      end
    end

    def configure_keys(keys, account)
      debug "configure_keys: keys:'#{keys.inspect}', account:'#{account.inspect}'"

      new_keys = []   
      keys.each do |k|
        if k.kind_of?(OMF::SFA::Model::Key)
          new_keys << k.ssh_key unless new_keys.include?(k.ssh_key)
        elsif k.kind_of?(String)
          new_keys << k unless new_keys.include?(k)
        end
      end

      OmfCommon.comm.subscribe('user_factory') do |user_rc|
        unless user_rc.error?

          user_rc.create(:user, hrn: 'existing_user', username: account.name) do |reply_msg|
            if reply_msg.success?
              u = reply_msg.resource

              u.on_subscribed do

                u.configure(auth_keys: new_keys) do |reply|
                  if reply.success?
                    release_proxy(user_rc, u)
                  else
                    error "Configuration of the public keys failed - #{reply[:reason]}"
                  end
                end
              end
            else
              error ">>> Resource creation failed - #{reply_msg[:reason]}"
            end
          end
        else
          raise UnknownResourceException.new "Cannot find resource's pubsub topic: '#{user_rc.inspect}'"
        end
      end
    end

    def create_resource(resource, lease, component)
      resource.create(component.resource_type.to_sym, hrn: component.name, uuid: component.uuid) do |reply_msg|
        if reply_msg.success?
          new_res = reply_msg.resource

          new_res.on_subscribed do
            info ">>> Connected to newly created node #{reply_msg[:hrn]}(id: #{reply_msg[:res_id]})"
            release_resource(resource, new_res, lease, component)
          end
        else
          error ">>> Resource creation failed - #{reply_msg[:reason]}"
        end
      end
    end

    def release_resource(resource, new_res, lease, component)

      release_timer = EventMachine::Timer.new(lease[:valid_until] - Time.now) do
        @leases[lease][component.id] = {:end => release_timer}
        resource.release(new_res) do |reply_msg|
          info "Node #{reply_msg[:res_id]} released"
          @leases[lease].delete(component.id)
          @leases.delete(lease) if @leases[lease].empty?
        end
      end
    end


    # It will start a monitoring job to nagios api for the given resource and lease
    #
    # @param [Resource] target resource for monitoring
    # @param [Lease]    lease Contains the lease information "valid_from" and
    #                   "valid_until"
    # @param [String]   oml_uri contains the uri for the oml server, if nil get default value from the config file.
    #
    def start_resource_monitoring(resource, lease, oml_uri=nil)
      return false if resource.nil? || lease.nil?
      nagios_url = @config[:nagios_url] || 'http://10.64.86.230:4567'
      oml_uri ||= @config[:default_oml_url]
      oml_domain = "monitoring_#{lease.account.name}_#{resource.name}"
      debug "start_resource_monitoring: resource: #{resource.inspect} lease: #{lease.inspect} oml_uri: #{oml_uri}"
      start_at = lease[:valid_from]
      interval = 10
      duration = lease[:valid_until] - lease[:valid_from]

      services = []

      checkhostalive = {name: "checkhostalive"}
      checkhostalive['uri'] = oml_uri
      checkhostalive['domain'] = oml_domain
      checkhostalive['metrics'] = ["plugin_output", "long_plugin_output"]
      checkhostalive['interval'] = interval
      checkhostalive['duration'] = duration
      checkhostalive['start_at'] = start_at
      services << checkhostalive

      # cpuusage = {name: "Cpu_Usage"}
      # cpuusage['uri'] = oml_uri
      # cpuusage['domain'] = oml_domain
      # cpuusage['metrics'] = ["plugin_output", "long_plugin_output"]
      # cpuusage['interval'] = interval
      # cpuusage['duration'] = duration
      # cpuusage['start_at'] = start_at
      # services << cpuusage

      # memory = {name: "Memory"}
      # memory['uri'] = oml_uri
      # memory['domain'] = oml_domain
      # memory['metrics'] = ["plugin_output", "long_plugin_output"]
      # memory['interval'] = interval
      # memory['duration'] = duration
      # memory['start_at'] = start_at
      # services << memory

      # iftraffic = {name: "Interface_traffic"}
      # iftraffic['uri'] = oml_uri
      # iftraffic['domain'] = oml_domain
      # iftraffic['metrics'] = ["plugin_output", "long_plugin_output"]
      # iftraffic['interval'] = interval
      # iftraffic['duration'] = duration
      # iftraffic['start_at'] = start_at
      # services << iftraffic


      services.each do |s|
        debug "Starting monitoring service: #{s[:name]}"
        url = "#{nagios_url}/hosts/#{resource.name}/services/#{s[:name]}/monitoring"
        s.delete(:name)

        debug "url: #{url} - data: #{s.inspect}"
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri)
        request.body = s.to_json
        begin
          out = http.request(request)
        rescue Errno::ECONNREFUSED
          debug "connection to #{url} refused."
          return false
        end
        debug "output: #{out.body.inspect}"
      end

      unless resource.monitoring
        mon = {}
        mon[:oml_url] = oml_uri
        mon[:domain] = oml_domain
        resource.monitoring = mon
      end
      true
    end

    def on_lease_start(lease)
      debug "on_lease_start: lease: '#{lease.inspect}'"
      # TODO configure openflow switch
      # TODO see if the child components have an image and load it 
    end

    def on_lease_end(lease)
      debug "on_lease_end: lease: '#{lease.inspect}'"
      # TODO release openflow switch
      # TODO shutdown all components
    end

    def provision(resources, sliver_type=nil, authorizer)
      debug "provision: resources: '#{resources.inspect}', sliver_type: #{sliver_type.inspect} #{sliver_type.nil?}"

      if sliver_type.nil?
        unless leases_only?(resources)
          return {error: "sliver_type not provided but resources contain at least one non lease type resource."}
        end      
        node_groups = group_nodes_for_provisioning(resources)
      else
        leases = []
        nodes = []
        resources.each do |resource| #we want to provision nodes and leases only
          case resource.resource_type
          when 'lease'
            leases << resource
          when 'node'
            nodes << resource
          end
        end
        node_groups = {}
        node_groups = group_nodes_for_provisioning(leases) unless leases.empty?
        nodes.each do |node|
          domain = node.domain
          sliver_type_uuid = sliver_type.uuid
          node_groups[sliver_type_uuid] = {} unless node_groups[sliver_type_uuid]
          node_groups[sliver_type_uuid][domain] = [] unless node_groups[sliver_type_uuid][domain]
          node_groups[sliver_type_uuid][domain] << node
        end
      end

      load_jobs = []
      node_groups.each do |sliver_type_uuid, domains|
        domains.each do |domain, nodes|
          sliver_type = OMF::SFA::Model::SliverType.first(uuid: sliver_type_uuid)
          disk_image = sliver_type.disk_image
          res = load_image_on_nodes(disk_image, nodes, domain)
          res[:nodes].each do |node|
            node = node.length == 1 ? "node00#{node}" : node.length == 2 ? "node0#{node}" : "node#{node}"
          end
          load_jobs << res
        end
      end

      Thread.new {
        jobs_done = []
        loop do
          done = false
          load_jobs.each do |job|
            job_id = job[:job_id]
            job_info = get_job_status(job_id)
            debug "JOB_INFO: #{job_info.inspect}"
            if job_info['status'] == 'complete' || job_info['status'] == 'failed' || job_info['status'] == 'cancelled'
              job_info["nodes"].each do |node, status|
                node_name = node.length == 1 ? "node00#{node}" : node.length == 2 ? "node0#{node}" : "node#{node}"
                node = find_in_resources_by_name(resources, node_name)
                if node.account.id != 2
                  node.status = job_info['status'] == 'complete' ? 'geni_provisioned' : 'geni_unallocated'
                  node.save
                else
                  debug "Managed node '#{node.name}' provision ended with status '#{status}'"
                end
              end
              jobs_done << job
              done = true if jobs_done.length == load_jobs.length
            end
          end
          break if done
          sleep 10
        end
        jobs_done.each do |job|
          job[:nodes].each do |node, status|
            node = node.to_s
            node_name = node.length == 1 ? "node00#{node}" : node.length == 2 ? "node0#{node}" : "node#{node}"
            node = find_in_resources_by_name(resources, node_name)
            action = status == 'failed' ? 'stop' : 'reset'
            change_node_status(node, action)
          end
        end
      }

      load_jobs
    end

    def get_node_status(node)
      descr = {name: node, account_id: 2}
      node  = OMF::SFA::Model::Node.first(descr) unless node.kind_of? OMF::SFA::Model::Resource
      server_url, user, token = create_base_cm_url(node.domain)
      node_id = node.name[-3..-1].to_i
      url = "#{server_url}/resources/node/#{node_id}?user=#{user}&token=#{token}"
      
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      
      begin
        out = http.request(request)
      rescue Errno::ECONNREFUSED
        debug "connection to #{url} refused."
        return false
      end
      JSON.parse(out.body)
    end

    def get_job_status(job_id)
      @rest_end_points.each do |end_point|
        url = "#{end_point[:url]}/jobs/#{job_id}?user=#{end_point[:user]}&token=#{end_point[:token]}"
        
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Get.new(uri.request_uri)
        
        begin
          out = http.request(request)
          if out.nil? || out.body.nil? || out.body == 'null' || out.kind_of?(Net::HTTPNotFound)
            next
          else
            response = JSON.parse(out.body)
            response['domain'] = end_point[:url]
            return response
          end
        rescue Errno::ECONNREFUSED
          debug "connection to #{url} refused."
          next
        end      
      end
      {error: "job with job_id: '#{job_id}' was not found."}
    end

    def change_node_status(node, status)
      debug "change_node_status: node: #{node.inspect} status: #{status}" 
      descr = {name: node, account_id: 2}
      node  = OMF::SFA::Model::Node.first(descr) unless node.kind_of? OMF::SFA::Model::Resource
      mac   = nil
      ip    = nil
      cm_ip = node.cmc.ip.address
      interfaces = node.parent ? node.parent.interfaces : node.interfaces
      interfaces.each do |iface|
        if iface.role == 'control'
          mac = iface.mac
          ip = iface.ips.first.address
        end
      end
      server_url, user, token = create_base_cm_url(node.domain)
      node_id     = node.name[-3..-1].to_i
      url         = "#{server_url}/resources/node/#{node_id}?user=#{user}&token=#{token}"
      
      uri          = URI.parse(url)
      http         = Net::HTTP.new(uri.host, uri.port)
      request      = Net::HTTP::Put.new(uri.request_uri, initheader = {'Content-Type' =>'application/json'})
      request.body = {state: status, mac: mac, ip: ip, cm_ip: cm_ip}.to_json
      
      begin
        out = http.request(request)
      rescue Errno::ECONNREFUSED
        debug "connection to #{url} refused."
        return false
      end
      JSON.parse(out.body)
    end

    def save_node_image(node, image_name)
      descr = {name: node, account_id: 2}
      node = OMF::SFA::Model::Node.first(descr) unless node.kind_of? OMF::SFA::Model::Resource
      mac = nil
      ip = nil
      node.interfaces.each do |iface|
        mac = iface.mac if iface.role == 'control'
        ip = iface.ips.first.address if iface.role == 'control'
      end
      server_url, user, token = create_base_cm_url(node.domain)
      node_id = node.name[-3..-1].to_i
      url = "#{server_url}/resources/node/#{node_id}?user=#{user}&token=#{token}"
      
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Put.new(uri.request_uri, initheader = {'Content-Type' =>'application/json'})
      request.body = {state: 'save', image: image_name, mac: mac, ip: ip}.to_json
      
      begin
        out = http.request(request)
        body = JSON.parse(out.body, :symbolize_names => true)
        out_job_id = body[:job_id]
        out_node = body[:node]
      rescue Errno::ECONNREFUSED
        debug "connection to #{url} refused."
        return false
      end
      JSON.parse(out.body)
    end

    def load_image_on_nodes(disk_image, nodes, domain)
      debug "load_image_on_nodes: disk_image: #{disk_image.inspect} nodes: #{nodes.inspect}"
      all_nodes = []
      macs      = []
      ips       = []
      cm_ips    = []
      nodes.each do |node|
        unless node.kind_of? OMF::SFA::Model::Node
          node_desc = {name: node, account_id: 2}
          node = OMF::SFA::Model::Node.first(node_desc) 
          next if node.nil? || node.empty?
        end
        all_nodes << node.name[-3..-1]
        interfaces = node.parent ? node.parent.interfaces : node.interfaces
        interfaces.each do |iface|
          macs << iface.mac if iface.role == 'control'
          ips << iface.ips.first.address if iface.role == 'control'
        end
        cm_ips << node.cmc.ip.address
      end

      disk_image = disk_image.path if disk_image.kind_of? OMF::SFA::Model::DiskImage

      server_url, user, token = create_base_cm_url(domain)
      node_id = nodes.first.name[-3..-1].to_i
      url = "#{server_url}/resources/node/#{node_id}?user=#{user}&token=#{token}"
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Put.new(uri.request_uri, initheader = {'Content-Type' =>'application/json'})
      request.body = {state: 'load', image: disk_image, nodes: all_nodes, macs: macs, ips: ips, cm_ips: cm_ips}.to_json

      begin
        out = http.request(request)
        body = JSON.parse(out.body, :symbolize_names => true)
      rescue Errno::ECONNREFUSED
        debug "connection to #{url} refused."
        return false
      end
      body
    end

    def operational_action(resources, action, options, authorizer)
      debug "operational_action: resources: #{resources.inspect} action: #{action} options: #{options.inspect}"
      value = []
      
      case action
      when "geni_start", "start", "on"
        action = "on"
      when "geni_stop", "stop", "off"
        action = "off"
      when "geni_restart", "restart", "reset"
        action = "reset"
      else
        return [13, '', "Operational action '#{action}' is not supported."]
      end

      resources.each do |resource|
        case resource.resource_type
        when 'lease'
          next if resource.components.nil?
          resource.components.each do |node|
            next if node.parent.nil?
            change_node_status(node, action)
          end
          tmp = {}
          tmp[:geni_sliver_urn] = resource.urn
          tmp[:geni_expires] = resource.valid_until.to_s
          tmp[:geni_allocation_status]  = resource.allocation_status
          tmp[:geni_operational_status]  = resource.operational_status
          value << tmp
        when 'node'
          change_node_status(resource, action)
          value << resource
        end
      end

      [0, value, '']
    end

    private

    def release_proxy(parent, child)
      parent.release(child) do |reply_msg|
        unless reply_msg.success?
          error "Release of the proxy #{child} failed - #{reply_msg[:reason]}"
        end
      end
    end

    def group_nodes_for_provisioning(leases)
      out = {}
      leases.each do |lease|
        lease.components.each do |comp|
          next if comp.parent.nil?
          sliver_type_uuid = comp.sliver_type.nil? ? @default_sliver_type.uuid : comp.sliver_type.uuid
          out[sliver_type_uuid] = {} unless out[sliver_type_uuid]
          out[sliver_type_uuid][comp.domain] = [] unless out[sliver_type_uuid][comp.domain]
          out[sliver_type_uuid][comp.domain] << comp
        end
      end
      out
    end

    def leases_only?(resources)
      resources.each do |resource|
        return false if resource.resource_type != 'lease'
      end
      true
    end

    def find_in_resources_by_name(resources, name)
      out = nil
      resources.each do |resource|
        if resource.resource_type == "lease"
          resource.components.each do |comp|
            out = comp if comp.name == name && comp.parent
          end
        else
          out = resource if resource.name == name
        end
      end
      out
    end

    def create_base_cm_url(domain)
      default_end_point = nil
      @rest_end_points.each do |end_point|
        if end_point[:domain] == domain
          return [end_point[:url], end_point[:user], end_point[:token]]
        end
        if end_point[:domain] == 'DEFAULT'
          default_end_point = end_point
        end
      end
      default_end_point = DEFAULT_REST_END_POINT unless default_end_point
      [default_end_point[:url], default_end_point[user], default_end_point, token]
    end
  end # AMLiaison
end # OMF::SFA::AM
