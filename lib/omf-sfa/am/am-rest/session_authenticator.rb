
require 'omf_common/lobject'
require 'omf-sfa/am/am-rest/am_authorizer'
require 'rack'


module OMF::SFA::AM::Rest
  class SessionAuthenticator < OMF::Common::LObject

    def self.active?
      @@active
    end

    def self.authenticated?
      self[:authenticated]
    end

    def self.authenticate
      self[:authenticated] = true
      self[:valid_until] = Time.now + @@expire_after
    end

    def self.logout
      self[:authenticated] = false
    end

    @@store = {}

    def self.[](key)
      (@@store[key] || {})[:value]
    end

    def self.[]=(key, value)
      @@store[key] = {:value => value, :time => Time.now } # add time for GC
    end

    @@active = false
    # Expire authenticated session after being idle for that many seconds
    @@expire_after = 2592000

    #
    # opts -
    #   :no_session - Array of regexp to ignore
    #
    def initialize(app, opts = {})
      @app = app
      @opts = opts
      @opts[:no_session] = (@opts[:no_session] || []).map { |s| Regexp.new(s) }
      if @opts[:expire_after]
        @@expire_after = @opts[:expire_after]
      end
      @@active = true
    end


    def call(env)
      req = ::Rack::Request.new(env)
      method = req.request_method
      # sid = nil
      path_info = req.path_info
      #puts "REQUEST(#{self.object_id}): #{path_info}"

      # unless @opts[:no_session].find {|rx| rx.match(path_info) }
      #   # unless sid = req.cookies['sid']
      #   #   sid = "s#{(rand * 10000000).to_i}_#{(rand * 10000000).to_i}"
      #   #   debug "Setting session for '#{req.path_info}' to '#{sid}'"
      #   # end
      #   # Thread.current["sessionID"] = sid
      #   # If 'login_url' is defined, check if this session is authenticated
      #   login_url = @opts[:login_url]
      #   if login_url
      #     unless login_url == req.path_info
      #       puts ">>>>>> CHECKING FOR LOGIN #{login_url.class}"
      #       if authenticated = self.class[:authenticated]
      #         # Check if it hasn't imed out
      #         if self.class[:valid_until] < Time.now
      #           debug "Session '#{sid}' expired"
      #           authenticated = false
      #         end
      #       end
      #       unless authenticated
      #         return [301, {'Location' => login_url, "Content-Type" => ""}, ['Login first']]
      #       end
      #     end
      #   else
      #     # init_fake_root
      #   end
      #   self.class[:valid_until] = Time.now + @@expire_after
      # end

      if method == 'GET'
        req.session[:authorizer] = AMAuthorizer.create_for_rest_request(env['rack.authenticated'], env['rack.peer_cert'], req.params["account"], @opts[:am_manager])
      elsif method == 'OPTIONS'
        #do nothing for OPTIONS  
      elsif env["REQUEST_PATH"] == '/mapper'
        req.session[:authorizer] = AMAuthorizer.create_for_rest_request(env['rack.authenticated'], env['rack.peer_cert'], req.params["account"], @opts[:am_manager])
      else
        body = req.body
        raise EmptyBodyException.new if body.nil?
        (body = body.string) if body.is_a? StringIO
        if body.is_a? Tempfile
          tmp = body
          body = body.read
          tmp.rewind
        end
        raise EmptyBodyException.new if body.empty?

        content_type = req.content_type
        raise UnsupportedBodyFormatException.new unless content_type == 'application/json'

        jb = JSON.parse(body)
        account = nil
        if jb.kind_of? Hash
          account = jb['account'].nil? ? nil : jb['account']['name']
        end
        
        req.session[:authorizer] = AMAuthorizer.create_for_rest_request(env['rack.authenticated'], env['rack.peer_cert'], account, @opts[:am_manager])
      end

      status, headers, body = @app.call(env)
      # if sid
      #   headers['Set-Cookie'] = "sid=#{sid}"  ##: name2=value2; Expires=Wed, 09-Jun-2021 ]
      # end
      [status, headers, body]
    rescue OMF::SFA::AM::InsufficientPrivilegesException => ex
      body = {
        :error => {
          :reason => ex.to_s,
        }
      }
      warn "ERROR: #{ex}"
      # debug ex.backtrace.join("\n")
      
      return [401, { "Content-Type" => 'application/json', 'Access-Control-Allow-Origin' => '*', 'Access-Control-Allow-Methods' => 'GET, PUT, POST, OPTIONS' }, JSON.pretty_generate(body)]
    rescue EmptyBodyException => ex
      body = {
        :error => {
          :reason => ex.to_s,
        }
      }
      warn "ERROR: #{ex}"
      # debug ex.backtrace.join("\n")
      
      return [400, { "Content-Type" => 'application/json', 'Access-Control-Allow-Origin' => '*', 'Access-Control-Allow-Methods' => 'GET, PUT, POST, OPTIONS' }, JSON.pretty_generate(body)]
    rescue UnsupportedBodyFormatException => ex
      body = {
        :error => {
          :reason => ex.to_s,
        }
      }
      warn "ERROR: #{ex}"
      # debug ex.backtrace.join("\n")
      
      return [400, { "Content-Type" => 'application/json', 'Access-Control-Allow-Origin' => '*', 'Access-Control-Allow-Methods' => 'GET, PUT, POST, OPTIONS' }, JSON.pretty_generate(body)]
    end

    @@def_authenticator = nil

    # def init_fake_root
    #   unless @@def_authenticator
    #     auth = {}
    #     [
    #       # ACCOUNT
    #       :can_create_account?, # ()
    #       :can_view_account?, # (account)
    #       :can_renew_account?, # (account, until)
    #       :can_close_account?, # (account)
    #       # RESOURCE
    #       :can_create_resource?, # (resource_descr, type)
    #       :can_modify_resource?, # (resource_descr, type)
    #       :can_view_resource?, # (resource)
    #       :can_release_resource?, # (resource)
    #       # LEASE
    #       :can_create_lease?, # (lease)
    #       :can_view_lease?, # (lease)
    #       :can_modify_lease?, # (lease)
    #       :can_release_lease?, # (lease)
    #     ].each do |m| auth[m] = true end
    #     require 'omf-sfa/am/default_authorizer'
    #     @@def_authenticator = OMF::SFA::AM::DefaultAuthorizer.new(auth)
    #   end
    #   Thread.current["authenticator"] = @@def_authenticator
    # end

  end # class

end # module




