
require 'nokogiri'
require 'time'
require 'zlib'
require 'base64'
require 'openssl'

require 'omf-sfa/am/am-rpc/abstract_rpc_service'
require 'omf-sfa/am/am-rpc/am_authorizer'

require 'omf-sfa/am/am-rpc/am_rpc_api'
require 'omf-sfa/resource/gurn'
require 'yaml'
#require 'omf-sfa/am/privilege_credential'
#require 'omf-sfa/am/user_credential'

module OMF::SFA::AM::RPC

  class NotAuthorizedException < XMLRPC::FaultException; end

  class AMService < AbstractService
    include OMF::Common::Loggable

    attr_accessor :authorizer

    #implement ServiceAPI
    implement AMServiceAPI


    def get_version(options = {})
      debug "GetVersion"

      config = YAML.load_file(File.dirname(__FILE__) + '/../../../../etc/omf-sfa/getVersion_ext.yaml')

      @return_struct[:geni_api] = 2
      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = {
        :geni_api => 2,
        :geni_api_versions => {
          2 => config[:url]
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
        #ans = {
        #  :code => {
        #    :geni_code => 1 # Bad Arguments
        #  },
        #  :output => "'geni_rspec_version' argument is missing."
        #}
        #return ans
      end
      unless rspec_version["type"].downcase.eql?("geni") && (rspec_version["version"].eql?("3.0") ||
                                                             rspec_version["version"].eql?("3"))
        @return_struct[:code][:geni_code] = 4 # Bad Version
        @return_struct[:output] = "'Version' or 'Type' of RSpecs are not the same with what 'GetVersion' returns."
        @return_struct[:value] = ''
        return @return_struct
        #ans = {
        #  :code => {
        #    :geni_code => 4 # Bad Version
        #  },
        #  :output => "'Version' or 'Type' of RSpecs are not the same with that 'GetVersion' returns."
        #}
        #return ans
      end

      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      if slice_urn
        resources = @manager.find_all_leases(authorizer.account, ["pending", "accepted", "active"], authorizer)
        resources.concat(@manager.find_all_components_for_account(authorizer.account, authorizer))
        # resources = @manager.find_all_resources_for_account(authorizer.account, authorizer)

        res = OMF::SFA::Model::Component.sfa_response_xml(resources, type: 'manifest').to_xml
      else
        resources = @manager.find_all_leases(nil, ["pending", "accepted", "active"], authorizer)
        comps = @manager.find_all_components_for_account(@manager._get_nil_account, authorizer)
        if only_available
          debug "only_available flag is true!"
          comps.delete_if {|c| !c.available}
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

      #{
      #  :code => {
      #    :geni_code => 0
      #  },
      #  :value => res
      #}
    rescue OMF::SFA::AM::InsufficientPrivilegesException => e
      @return_struct[:code][:geni_code] = 3
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct

      #{
      #  :code => {
      #    :geni_code => 3
      #  },
      #  :output => e
      #}
    end

    def create_sliver(slice_urn, credentials, rspec_s, users, options)
      debug 'CreateSliver: SLICE URN: ', slice_urn, ' RSPEC: ', rspec_s, ' USERS: ', users.inspect

      if slice_urn.nil? || credentials.nil? || rspec_s.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "Some of the following arguments are missing: 'slice_urn', 'credentials', 'rspec'"
        @return_struct[:value] = ''
        return @return_struct
      end

      #@authorizer.check_credentials(slice_urn, credentials.first, @manager)
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
      end

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

      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = res
      @return_struct[:output] = ''
      return @return_struct

      #{ :code => {
      #    :geni_code => 0
      #  },
      #  :value => res
      #}
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

    def sliver_status(slice_urn, credentials, options)
      debug('SliverStatus for ', slice_urn)
      #@authorizer.check_credentials(slice_urn, credentials.first, @manager)


      if slice_urn.nil? || credentials.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "Some of the following arguments are missing: 'slice_urn', 'credentials'"
        @return_struct[:value] = false
        return @return_struct
      end
      #@authorizer.check_credentials(slice_urn, credentials.first, @manager)
      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)
      #raise OMF::SFA::AM::InsufficientPrivilegesException.new("Account is closed.") if authorizer.account.closed?

      status = {}
      status['omf_expires_at'] = authorizer.account.valid_until.utc.strftime('%Y%m%d%H%M%SZ')

      resources = @manager.find_all_components_for_account(authorizer.account, authorizer)
      leases = @manager.find_all_leases(authorizer.account, ['accepted', 'active'], authorizer)
      # # only list independent resources
      # resources = resources.select {|r| r.independent_component?}

      unless resources.empty?
        status['geni_urn'] = slice_urn
        #status['geni_urn'] = "urn:publicid:IDN+omf:nitos+sliver+accdsw"

        # Any of the following configuring, ready, failed, and unknown
        status['geni_status'] = 'ready'

        status['geni_resources'] = resources.collect do |r|
          {
            'geni_urn'=> r.urn,
            'geni_status' => r.status,
            'geni_error' => '',
          }
        end

        geni_leases = leases.collect do |l|
          l_status = l.active? ? "ready" : "configuring"
          {
            'geni_urn'=> l.urn,
            'geni_status' => l_status,
            'geni_error' => '',
          }
        end
        status['geni_resources'] += geni_leases unless geni_leases.empty?
        @return_struct[:value] = status
      else
        @return_struct[:code][:geni_code] = 12 # SEARCH FAILED
        @return_struct[:output] = "Empty Slice."
        
        status['geni_urn'] = slice_urn
        status['geni_status'] = 'unallocated'
        status['geni_resources'] = []

        @return_struct[:value] = status
        return @return_struct
      end

      @return_struct[:code][:geni_code] = 0
      @return_struct[:output] = ''
      return @return_struct

      #{ :code => {
      #    :geni_code => 0
      #  },
      #  :value => status
      #}
    rescue OMF::SFA::AM::InsufficientPrivilegesException => e
      @return_struct[:code][:geni_code] = 3
      @return_struct[:output] = e.to_s
      @return_struct[:value] = false
      return @return_struct
    end

    def renew_sliver(slice_urn, credentials, expiration_time, options)
      debug('RenewSliver ', slice_urn, ' until <', expiration_time, '>')

      if slice_urn.nil? || credentials.nil? || expiration_time.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "Some of the following arguments are missing: 'slice_urn', 'credentials', 'expiration_time'"
        @return_struct[:value] = false
        return @return_struct
      end

      if expiration_time.kind_of?(XMLRPC::DateTime)
        expiration_time = expiration_time.to_time
      else
        expiration_time = Time.parse(expiration_time)
      end
      debug('RenewSliver ', slice_urn, ' until <', expiration_time, '>')
      #authorizer.check_credentials(slice_urn, credentials.first, @manager)
      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      @manager.renew_account_until({ :urn => slice_urn }, expiration_time, authorizer)

      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = true
      @return_struct[:output] = ''
      return @return_struct

      #{ :code => {
      #    :geni_code => 0
      #  },
      #  :value => true
      #}
    rescue OMF::SFA::AM::UnavailableResourceException => e
      @return_struct[:code][:geni_code] = 12 # Search Failed
      @return_struct[:output] = e.to_s
      @return_struct[:value] = false
      return @return_struct
    rescue OMF::SFA::AM::InsufficientPrivilegesException => e
      @return_struct[:code][:geni_code] = 3
      @return_struct[:output] = e.to_s
      @return_struct[:value] = false
      return @return_struct
    end

    # close the account and release the attached resources
    def delete_sliver(slice_urn, credentials, options)
      debug('DeleteSliver ', slice_urn)

      if slice_urn.nil? || credentials.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:output] = "Some of the following arguments are missing: 'slice_urn', 'credentials'"
        @return_struct[:value] = ''
        return @return_struct
      end

      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      # close account and release resources
      account = @manager.close_account({ :urn => slice_urn }, authorizer)
      debug "Slice '#{slice_urn}' associated with account '#{account.id}:#{account.closed_at}'"

      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = true
      @return_struct[:output] = ''
      return @return_struct

      #{ :code => {
      #    :geni_code => 0
      #  },
      #  :value => true
      #}
    rescue OMF::SFA::AM::UnavailableResourceException => e
      @return_struct[:code][:geni_code] = 12 # Search Failed
      @return_struct[:output] = e.to_s
      @return_struct[:value] = ''
      return @return_struct
    end

    # close the account but do not release its resources
    def shutdown_sliver(slice_urn, credentials, options = {})
      #@authorizer.check_credentials(slice_urn, credentials.first, @manager)
      authorizer = OMF::SFA::AM::RPC::AMAuthorizer.create_for_sfa_request(slice_urn, credentials, @request, @manager)

      if slice_urn.nil? || credentials.nil?
        @return_struct[:code][:geni_code] = 1 # Bad Arguments
        @return_struct[:value] = ''
        @return_struct[:output] = "Some of the following arguments are missing: 'slice_urn', 'credentials'"
        return @return_struct
      end
      #puts "SLICE URN: #{slice_urn}"
      account = @manager.close_account({ :urn => slice_urn }, authorizer)

      @return_struct[:code][:geni_code] = 0
      @return_struct[:value] = true
      @return_struct[:output] = ''
      return @return_struct

      #{ :code => {
      #    :geni_code => 0
      #  },
      #  :value => true
      #}
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

  end # AMService

end # module



