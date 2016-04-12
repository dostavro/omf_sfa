
require 'nokogiri'
require 'time'
require 'zlib'
require 'base64'
require 'openssl'

require 'omf-sfa/am/am-rpc/abstract_rpc_service'
require 'omf-sfa/am/am-rpc/am_authorizer'

require 'omf-sfa/am/am-rpc/v3/am_rpc_api'
require 'omf-sfa/resource/gurn'
require 'yaml'
#require 'omf-sfa/am/privilege_credential'
#require 'omf-sfa/am/user_credential'

module OMF::SFA::AM
  module RPC; end
end

module OMF::SFA::AM::RPC::V3

  class NotAuthorizedException < XMLRPC::FaultException; end

  class AMService < OMF::SFA::AM::RPC::AbstractService
    include OMF::Common::Loggable

    attr_accessor :authorizer

    #implement ServiceAPI
    implement OMF::SFA::AM::RPC::V3::AMServiceAPI


    def get_version(options = {})
      debug "GetVersion"

      config = YAML.load_file(File.dirname(__FILE__) + '/../../../../../etc/omf-sfa/getVersion_ext_v3.yaml')

      @return_struct[:geni_api] = 3
      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = {
        :geni_api => 3,
        :geni_api_versions => {
          3 => config[:url]
        },
        :geni_request_rspec_versions => [{
          :type => "geni",
          :version => "3",
          :schema => "http://www.geni.net/resources/rspec/3/request.xsd",
          :namespace => "http://www.geni.net/resources/rspec/3",
          :extensions => ["http://nitlab.inf.uth.gr/schema/sfa/rspec/1/request-reservation.xsd"]
        }],
        :geni_ad_rspec_versions => [{
          :type => "geni",
          :version => "3",
          :schema => "http://www.geni.net/resources/rspec/3/ad.xsd",
          :namespace => "http://www.geni.net/resources/rspec/3",
          :extensions => ["http://nitlab.inf.uth.gr/schema/sfa/rspec/1/ad-reservation.xsd"]
        }],
        :geni_credential_types => [{
          :geni_type => 'geni_sfa',
          :geni_version => 3,
        }],
        :omf_am => "0.1"
      }
      @return_struct[:value].merge!(config[:getversion]) unless config[:getversion].nil?
      @return_struct[:output] = ''

      return @return_struct
    end

    def list_resources(credentials, options)
      debug 'ListResources: Options: ', options.inspect
      
      only_available = options["geni_available"]
      compressed = options["geni_compressed"]
      slice_urn = options["geni_slice_urn"]
      rspec_version = options["geni_rspec_version"]

      if rspec_version.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "'geni_rspec_version' argument is missing."
        @return_struct[:value] = ''
        return @return_struct
      end
      unless rspec_version["type"].downcase.eql?("geni") && (!rspec_version["version"].eql?("3.0") ||
                                                             !rspec_version["version"].eql?("3"))
        @return_struct[:code][:geni_code] = 4 # Bad Version
        @return_struct[:output] = "'Version' or 'Type' of RSpecs are not the same with what 'GetVersion' returns."
        @return_struct[:value] = ''
        return @return_struct
      end

      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      if slice_urn
        @return_struct[:code][:geni_code] = 4 # Bad Version
        @return_struct[:output] = "Geni version 3 no longer supports arguement 'geni_slice_urn' for list resources method, please use describe instead."
        @return_struct[:value] = ''
        return @return_struct
      else
        resources = @manager.find_all_leases(nil, ["pending", "accepted", "active"], authorizer)
        comps = @manager.find_all_components_for_account(@manager._get_nil_account, authorizer)
        if only_available
          debug "only_available flag is true!"
          comps.delete_if {|c| !c.available_now?}
        end
        resources.concat(comps)
        res = OMF::SFA::Model::Component.sfa_response_xml(resources, type: 'advertisement').to_xml
      end

      #res = OMF::SFA::Resource::OComponent.sfa_advertisement_xml(resources).to_xml
      if compressed
	      res = Base64.encode64(Zlib::Deflate.deflate(res))
      end

      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = res
      @return_struct[:output] = ''
      return @return_struct
    rescue OMF::SFA::AM::InsufficientPrivilegesException => e
      @return_struct[:code][:geni_code] = 3
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    end

    def describe(urns, credentials, options)
      debug 'Describe: URNS: ', urns.inspect, ' Options: ', options.inspect

      if urns.nil? || urns.empty?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "Arguement 'urns' is either empty or nil."
        @return_struct[:value] = ''
        return @return_struct
      end

      compressed = options["geni_compressed"]
      rspec_version = options["geni_rspec_version"]

      if rspec_version.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "'geni_rspec_version' argument is missing."
        @return_struct[:value] = ''
        return @return_struct
      end
      unless rspec_version["type"].downcase.eql?("geni") && (!rspec_version["version"].eql?("3.0") ||
                                                             !rspec_version["version"].eql?("3"))
        @return_struct[:code][:geni_code] = 4 # Bad Version
        @return_struct[:output] = "'Version' or 'Type' of RSpecs are not the same with what 'GetVersion' returns."
        @return_struct[:value] = ''
        return @return_struct
      end

      slice_urn, slivers_only, error_code, error_msg = parse_urns(urns)
      if error_code != 0
        @return_struct[:code][:geni_code] = error_code
        @return_struct[:output] = error_msg
        @return_struct[:value] = ''
        return @return_struct
      end

      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      resources = []
      leases = []
      if slivers_only
        urns.each do |urn|
          l = @manager.find_lease({urn: urn}, authorizer)
          resources << l
          leases << l
          l.components.each do |comp|
            resources << comp if comp.account.id == authorizer.account.id
          end
        end
      else
        resources =  @manager.find_all_leases(authorizer.account, ["pending", "accepted", "active"], authorizer)
        leases = resources.dup
        resources.concat(@manager.find_all_components_for_account(authorizer.account, authorizer))
      end
      
      res = OMF::SFA::Model::Component.sfa_response_xml(resources, type: 'manifest').to_xml
      value = {}
      value[:geni_rspec] = res
      value[:geni_urn] = slice_urn
      value[:geni_slivers] = []
      leases.each do |lease|
        tmp = {}
        tmp[:geni_sliver_urn]         = lease.urn
        tmp[:geni_expires]            = lease.valid_until.to_s
        tmp[:geni_allocation_status]  = lease.allocation_status
        tmp[:geni_operational_status] = lease.operational_status
        value[:geni_slivers] << tmp
      end

      if compressed
        res = Base64.encode64(Zlib::Deflate.deflate(res))
      end

      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = value
      @return_struct[:output] = ''
      return @return_struct
    rescue OMF::SFA::AM::InsufficientPrivilegesException => e
      @return_struct[:code][:geni_code] = 3
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    end

    def allocate(urns, credentials, rspec_s, options)
      debug 'Allocate: URNs: ', urns, ' RSPEC: ', rspec_s, ' Options: ', options.inspect, "time: ", Time.now

      if urns.nil? || credentials.nil? || rspec_s.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "Some of the following arguments are missing: 'urns', 'credentials', 'rspec'"
        @return_struct[:value] = ''
        return @return_struct
      end

      if urns.kind_of? String
        tmp = urns
        urns = []
        urns << tmp
      end

      slice_urn, slivers_only, error_code, error_msg = parse_urns(urns)
      if error_code != 0
        @return_struct[:code][:geni_code] = error_code
        @return_struct[:output] = error_msg
        @return_struct[:value] = ''
        return @return_struct
      end

      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      rspec = Nokogiri::XML.parse(rspec_s)
      resources = @manager.update_resources_from_rspec(rspec.root, true, authorizer)

      leases_only = true
      resources.each do |res|
        if res.resource_type != 'lease'
          leases_only = false
          break
        end
      end

      if resources.nil? || resources.empty? || leases_only
        debug('CreateSliver failed', "all the requested resources were unavailable for the requested DateTime.")

        resources.each do |res|
          @manager.get_scheduler.delete_lease(res) if res.status == 'pending'
        end

        @return_struct[:code][:geni_code] = 7 # operation refused
        @return_struct[:output] = "all the requested resources were unavailable for the requested DateTime."
        @return_struct[:value] = ''
        return @return_struct
      else
        resources.each do |res|
          if res.resource_type == 'node'
            res.status = 'geni_allocated'
            res.save
          end
        end
      end

      res = OMF::SFA::Model::Component.sfa_response_xml(resources, {:type => 'manifest'}).to_xml
      value = {}
      value[:geni_rspec] = res
      value[:geni_slivers] = []
      resources.each do |r|
        if r.resource_type == 'lease'
          tmp = {}
          tmp[:geni_sliver_urn] = r.urn
          tmp[:geni_expires] = r.valid_until.to_s
          tmp[:geni_allocation_status]  = r.status == 'accepted' || r.status == 'active' ? 'geni_allocated' : 'geni_unallocated'
          value[:geni_slivers] << tmp
        end
      end

      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = value
      @return_struct[:output] = ''
      return @return_struct
    rescue OMF::SFA::AM::InsufficientPrivilegesException => e
      @return_struct[:code][:geni_code] = 3
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    rescue OMF::SFA::AM::UnknownResourceException => e
      debug('CreateSliver Exception', e.to_s)
      @return_struct[:code][:geni_code] = 12 # Search Failed
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    rescue OMF::SFA::AM::FormatException => e
      debug('CreateSliver Exception', e.to_s)
      @return_struct[:code][:geni_code] = 4 # Bad Version
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    rescue OMF::SFA::AM::UnavailableResourceException => e
      @return_struct[:code][:geni_code] = 3
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    end

    def provision(urns, credentials, options)
      debug 'Provision: URNs: ', urns, ' Options: ', options.inspect, "time: ", Time.now

      if urns.nil? || credentials.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "Some of the following arguments are missing: 'slice_urn', 'credentials', 'rspec'"
        @return_struct[:value] = ''
        return @return_struct
      end

      slice_urn, slivers_only, error_code, error_msg = parse_urns(urns)
      if error_code != 0
        @return_struct[:code][:geni_code] = error_code
        @return_struct[:output] = error_msg
        @return_struct[:value] = ''
        return @return_struct
      end

      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      resources = []
      leases = []
      if slivers_only
        urns.each do |urn|
          l = @manager.find_lease({urn: urn}, authorizer)
          next unless l.status == "active"
          resources << l 
          leases << l
          l.components.each do |comp|
            resources << comp if comp.account.id == authorizer.account.id
          end
        end
      else
        resources = @manager.find_all_leases(authorizer.account, ["active"], authorizer) #You can provision only active leases
        leases = resources.dup
        resources.concat(@manager.find_all_components_for_account(authorizer.account, authorizer))
      end

      if leases.nil? || leases.empty?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "There are no active slivers for slice: '#{slice_urn}'."
        @return_struct[:value] = ''
        return @return_struct
      end

      users = options['geni_users'] || []
      debug "Users: #{users.inspect}"
      all_keys = []
      users.each do |user|
        gurn = OMF::SFA::Model::GURN.parse(user["urn"])
        u = @manager.find_or_create_user({urn: gurn.urn}, user["keys"])
        u.keys.each do |k|
          all_keys << k unless all_keys.include? k
        end
        unless authorizer.account.users.include?(u) 
          authorizer.account.add_user(u) 
          authorizer.account.save
        end
      end
      @liaison.configure_keys(all_keys, authorizer.account)

      res = OMF::SFA::Model::Component.sfa_response_xml(resources, {:type => 'manifest'}).to_xml
      value = {}
      value[:geni_rspec] = res
      value[:geni_slivers] = []
      resources.each do |resource|
        if resource.resource_type == 'lease'
          tmp = {}
          tmp[:geni_sliver_urn] = resource.urn
          tmp[:geni_expires] = resource.valid_until.to_s
          tmp[:geni_allocation_status]  = resource.allocation_status
          value[:geni_slivers] << tmp
        end
      end

      event_scheduler = @manager.get_scheduler.event_scheduler
      event_scheduler.in '10s' do
        debug "PROVISION STARTS #{leases.inspect}"
        @liaison.provision(leases, authorizer)
      end

      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = value
      @return_struct[:output] = ''
      return @return_struct
    rescue OMF::SFA::AM::InsufficientPrivilegesException => e
      @return_struct[:code][:geni_code] = 3
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    rescue OMF::SFA::AM::UnknownResourceException => e
      debug('CreateSliver Exception', e.to_s)
      @return_struct[:code][:geni_code] = 12 # Search Failed
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    rescue OMF::SFA::AM::FormatException => e
      debug('CreateSliver Exception', e.to_s)
      @return_struct[:code][:geni_code] = 4 # Bad Version
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    end

    def renew(urns, credentials, expiration_time, options)
      debug('Renew: URNs: ', urns.inspect, ' until <', expiration_time, '>')

      if urns.nil? || urns.empty? || credentials.nil? || expiration_time.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "Some of the following arguments are missing: 'slice_urn', 'credentials', 'expiration_time'"
        @return_struct[:value] = ''
        return @return_struct
      end

      if expiration_time.kind_of?(XMLRPC::DateTime)
        expiration_time = expiration_time.to_time
      else
        expiration_time = Time.parse(expiration_time)
      end

      slice_urn, slivers_only, error_code, error_msg = parse_urns(urns)
      if error_code != 0
        @return_struct[:code][:geni_code] = error_code
        @return_struct[:output] = error_msg
        @return_struct[:value] = ''
        return @return_struct
      end

      debug('Renew', slice_urn, ' until <', expiration_time, '>')

      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      leases = []
      if slivers_only
        urns.each do |urn|
          l = @manager.find_lease({urn: urn}, authorizer)
          leases << l
        end
      else
        leases =  @manager.find_all_leases(authorizer.account, ["accepted", "active"], authorizer)
      end

      if leases.nil? || leases.empty?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "There are no slivers for slice: '#{slice_urn}'."
        @return_struct[:value] = ''
        return @return_struct
      end

      @manager.renew_account_until({ :urn => slice_urn }, expiration_time, authorizer)

      value = {}
      value[:geni_urn] = slice_urn
      value[:geni_slivers] = []
      leases.each do |lease|
        lease.valid_until = Time.parse(expiration_time).utc
        lease.save
        tmp = {}
        tmp[:geni_sliver_urn]         = lease.urn
        tmp[:geni_expires]            = lease.valid_until.to_s
        tmp[:geni_allocation_status]  = lease.allocation_status
        tmp[:geni_operational_status] = lease.operational_status
        value[:geni_slivers] << tmp
      end

      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = value
      @return_struct[:output] = ''
      return @return_struct
    rescue OMF::SFA::AM::UnavailableResourceException => e
      @return_struct[:code][:geni_code] = 12 # Search Failed
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    rescue OMF::SFA::AM::InsufficientPrivilegesException => e
      @return_struct[:code][:geni_code] = 3
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    end

    def status(urns, credentials, options)
      debug('Status for ', urns.inspect, ' OPTIONS: ', options.inspect)

      if urns.nil? || credentials.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "Some of the following arguments are missing: 'slice_urn', 'credentials'"
        @return_struct[:value] = ''
        return @return_struct
      end

      slice_urn, slivers_only, error_code, error_msg = parse_urns(urns)
      if error_code != 0
        @return_struct[:code][:geni_code] = error_code
        @return_struct[:output] = error_msg
        @return_struct[:value] = ''
        return @return_struct
      end

      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      leases = []
      if slivers_only
        urns.each do |urn|
          l = @manager.find_lease({urn: urn}, authorizer)
          leases << l
        end
      else
        leases =  @manager.find_all_leases(authorizer.account, ["accepted", "active"], authorizer)
      end

      value = {}
      value[:geni_urn] = slice_urn
      value[:geni_slivers] = []
      leases.each do |lease|
        tmp = {}
        tmp[:geni_sliver_urn]         = lease.urn
        tmp[:geni_expires]            = lease.valid_until.to_s
        tmp[:geni_allocation_status]  = lease.allocation_status
        tmp[:geni_operational_status] = lease.operational_status
        value[:geni_slivers] << tmp
      end

      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = value
      @return_struct[:output] = ''
      return @return_struct
    rescue OMF::SFA::AM::InsufficientPrivilegesException => e
      @return_struct[:code][:geni_code] = 3
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    end

    def performOperationalAction(urns, credentials, action, options)
      debug('performOperationalAction: URNS: ', urns.inspect, ' Action: ', action, ' Options: ', options.inspect)
      
      if urns.nil? || credentials.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "Some of the following arguments are missing: 'slice_urn', 'credentials'"
        @return_struct[:value] = ''
        return @return_struct
      end

      slice_urn, slivers_only, error_code, error_msg = parse_urns(urns)
      if error_code != 0
        @return_struct[:code][:geni_code] = error_code
        @return_struct[:output] = error_msg
        @return_struct[:value] = ''
        return @return_struct
      end

      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      resources = []
      leases = []
      if slivers_only
        urns.each do |urn|
          l = @manager.find_lease({urn: urn}, authorizer)
          next unless l.status == "active"
          resources << l 
          leases << l
          l.components.each do |comp|
            resources << comp if comp.account.id == authorizer.account.id
          end
        end
      else
        resources = @manager.find_all_leases(authorizer.account, ["active"], authorizer) #You can provision only active leases
        leases = resources.dup
        resources.concat(@manager.find_all_components_for_account(authorizer.account, authorizer))
      end

      if leases.nil? || leases.empty?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "There are no active slivers for slice: '#{slice_urn}'."
        @return_struct[:value] = ''
        return @return_struct
      end

      code, value, output= @liaison.operational_action(leases, action, options, authorizer)

      @return_struct[:code][:geni_code] = code
      @return_struct[:value] = value
      @return_struct[:output] = output
      return @return_struct
    rescue OMF::SFA::AM::InsufficientPrivilegesException => e
      @return_struct[:code][:geni_code] = 3
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    end

    # close the account and release the attached resources
    def delete(urns, credentials, options)
      debug('DeleteSliver: URNS: ', urns.inspect, ' Options: ', options.inspect)

      if urns.nil? || urns.empty? || credentials.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "Some of the following arguments are missing: 'urns', 'credentials'"
        @return_struct[:value] = ''
        return @return_struct
      end

      slice_urn, slivers_only, error_code, error_msg = parse_urns(urns)
      if error_code != 0
        @return_struct[:code][:geni_code] = error_code
        @return_struct[:output] = error_msg
        @return_struct[:value] = ''
        return @return_struct
      end

      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)
      value = []
      if slivers_only
        urns.each do |urn|
          l = OMF::SFA::Model::Lease.first({urn: urn})
          tmp = {}
          tmp[:geni_sliver_urn] = urn
          tmp[:geni_allocation_status] = 'geni_unallocated'
          tmp[:geni_expires] = l.valid_until
          value << tmp
        end
      else
        ac = @manager.find_account({:urn => slice_urn}, authorizer)
        @manager.find_all_leases(ac, ['accepted', 'active'], authorizer).each do |l|
          tmp = {}
          tmp[:geni_sliver_urn] = l.urn
          tmp[:geni_allocation_status] = 'geni_unallocated'
          tmp[:geni_expires] = l.valid_until.to_s
          value << tmp
        end
        account = @manager.close_account(ac, authorizer)
        debug "Slice '#{slice_urn}' associated with account '#{account.id}:#{account.closed_at}'"
      end

      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = value
      @return_struct[:output] = ''
      return @return_struct
    rescue OMF::SFA::AM::UnavailableResourceException => e
      @return_struct[:code][:geni_code] = 12 # Search Failed
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    end

    # close the account but do not release its resources
    def shutdown_sliver(slice_urn, credentials, options = {})
      debug 'ShutdownSliver: SLICE URN: ', slice_urn, ' Options: ', options.insp

      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      if slice_urn.nil? || credentials.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:value] = ''
        @return_struct[:output] = "Some of the following arguments are missing: 'slice_urn', 'credentials'"
        return @return_struct
      end

      slice_urn, slivers_only, error_code, error_msg = parse_urns(urns)
      if error_code != 0
        @return_struct[:code][:geni_code] = error_code
        @return_struct[:output] = error_msg
        @return_struct[:value] = ''
        return @return_struct
      end

      account = @manager.close_account({ :urn => slice_urn }, authorizer)

      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = true
      @return_struct[:output] = ''
      return @return_struct
    end

    private

    def initialize(opts)
      super
      @manager = opts[:manager]
      @liaison = opts[:liaison]
      @return_struct = {
        :code => {
          :geni_code => ""
        },
        :value => '',
        :output => ''
      }
    end

    def parse_urns(urns)
      slice_urn = nil
      slivers_only = false

      urns.each do |urn|
        utype = urn_type(urn)
        if utype == "slice" || utype == "account"
          if urns.size != 1 # you can't send more than one slice urns
            return ['', '', 1, 'only one slice urn can be described.']
          end
          slice_urn = urn
          break
        elsif utype == 'lease' || utype == 'sliver'
          unless l = OMF::SFA::Model::Lease.first({urn: urn})
            return ['', '', 1, "Lease '#{urn}' does not exist."]
          end
          new_slice_urn = l.account.urn
          slice_urn = new_slice_urn if slice_urn.nil?
          if new_slice_urn != slice_urn
            return ['', '', 1, "All sliver urns must belong to the same slice."]
          end
          slivers_only = true
        else
          return ['', '', 1, "Only slivers or a slice can be described."]
        end
      end

      [slice_urn, slivers_only, 0, '']
    end

    def urn_type(urn)
      urn.split('+')[-2]
    end
  end # AMService
end # module
