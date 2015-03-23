# require 'rubygems'
require 'rack'
require 'rack/showexceptions'
require 'thin'
# require 'dm-migrations'
require 'omf_common/lobject'
require 'omf_common/load_yaml'
require 'sequel'
# require 'omf-sfa/resource'

require 'omf-sfa/am/am_runner'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_scheduler'
require 'omf-sfa/am/am_liaison'
require 'omf-sfa/am/am-xmpp/am_xmpp'

@@config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../../etc/omf-sfa'])[:omf_sfa_am]

module OMF::SFA::AM

  class AMServer
    # Don't use LObject as we haven't initialized the logging system yet. Happens in 'init_logger'
    include OMF::Common::Loggable
    extend OMF::Common::Loggable

    @@rpc = @@config[:endpoints].select { |v| v[:type] == 'xmlrpc' }.first
    @@xmpp = @@config[:endpoints].select { |v| v[:type] == 'xmpp' }.first


    def self.rpc_config
      @@rpc
    end

    def self.xmpp_config
      @@xmpp
    end

    def init_logger
      OMF::Common::Loggable.init_log 'am_server', :searchPath => File.join(File.dirname(__FILE__), 'am_server'), :environment => @@config[:operationMode]
    end

    def check_dependencies
      raise "xmlsec1 is not installed!" unless system('which xmlsec1 > /dev/null 2>&1')
    end

    def load_trusted_cert_roots

      trusted_roots = File.expand_path(@@rpc[:trusted_roots])
      certs = Dir.entries(trusted_roots)
      certs.delete("..")
      certs.delete(".")
      certs.each do |fn|
        fne = File.join(trusted_roots, fn)
        if File.readable?(fne)
          begin
            trusted_cert = OpenSSL::X509::Certificate.new(File.read(fne))
            OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.add_cert(trusted_cert)
          rescue OpenSSL::X509::StoreError => e
            if e.message == "cert already in hash table"
              warn "X509 cert '#{fne}' already registered in X509 store"
            else
              raise e
            end
          end
        else
          warn "Can't find trusted root cert '#{trusted_roots}/#{fne}'"
        end
      end
    end

    def init_db(options)
      debug "options: #{options}"

      # Configure the data store
      #
      # Sequel.connect('postgres://user:password@localhost/my_db')
      require 'sequel'
      Sequel.connect(options[:database])
      # puts 'requiring models'
      require 'omf-sfa/models' # Make sure Sequel has been connected to a db before loading the models
      OMF::SFA::Model::Constants.default_domain = @@config[:domain]
    end


    def load_test_am(options)
#       #require  'dm-migrations'
#       #DataMapper.auto_migrate!
#       #DataMapper.auto_upgrade!

#       am = options[:am][:manager]
#       if am.is_a? Proc
#         am = am.call
#         options[:am][:manager] = am
#       end

#       require 'omf-sfa/resource/account'
#       #account = am.find_or_create_account(:name => 'foo')
#       account = OMF::SFA::Model::Account.create(:name => 'root')

#       require 'omf-sfa/resource/link'
#       require 'omf-sfa/resource/node'
#       require 'omf-sfa/resource/interface'
#       # nodes = {}
#       # 3.times do |i|
#         # name = "n#{i}"
#         # nodes[name] = n = OMF::SFA::Resource::Node.create(:name => name)
#         # am.manage_resource(n)
#       # end

#       r = []
# #       r << l = OMF::SFA::Resource::Link.create(:name => 'l')
# #       r << OMF::SFA::Resource::Channel.create(:name => '1', :frequency => "2.412GHZ")
#       lease = OMF::SFA::Model::Lease.create(:account => account, :name => 'l1', :valid_from => Time.now, :valid_until => Time.now + 36000)
# #       2.times do |i|
# #         r << n = OMF::SFA::Resource::Node.create(:name => "node#{i}", :urn => OMF::SFA::Resource::GURN.create("node#{i}", :type => 'node'))
# #         ifr = OMF::SFA::Resource::Interface.create(name: "node#{i}:if0", node: n, channel: l)
# #         ip = OMF::SFA::Resource::Ip.create(address: "10.0.1.#{i}", netmask: "255.255.255.0", ip_type: "ipv4", interface: ifr)
# #         n.interfaces << ifr
# #         l.interfaces << ifr
# #         n.leases << lease
# #       end
# #       r.last.leases << OMF::SFA::Resource::Lease.create(:account => account, :name => 'l2', :valid_from => Time.now + 3600, :valid_until => Time.now + 7200)
#       r << n = OMF::SFA::Model::Node.create(:name => "node1", :urn => OMF::SFA::Model::GURN.create("node1", :type => 'node'))
#       ip1 = OMF::SFA::Model::Ip.create(address: "10.0.0.1", netmask: "255.255.255.0", ip_type: "ipv4")
#       ifr1 = OMF::SFA::Model::Interface.create(role: "control_network", name: "node1:if0", mac: "00-03-1d-0d-4b-96", node: n)
#       ifr1.add_ip(ip1)
#       ip2 = OMF::SFA::Model::Ip.create(address: "10.0.0.101", netmask: "255.255.255.0", ip_type: "ipv4")
#       ifr2 = OMF::SFA::Model::Interface.create(role: "cm_network", name: "node1:if1", mac: "09:A2:DA:0D:F1:01", node: n)
#       ifr2.add_ip(ip2)
#       n.interfaces << ifr1
#       n.interfaces << ifr2
#       n.add_lease(lease)
#       am.manage_resources(r)
    end

    def init_am_manager(opts = {})
      @am_manager = OMF::SFA::AM::AMManager.new(OMF::SFA::AM::AMScheduler.new(opts))
      opts.merge!({am: {manager: @am_manager}})
    end

    def run(opts)
      @am_manager = nil

      # alice = OpenSSL::X509::Certificate.new(File.read('/Users/max/.gcf/alice-cert.pem'))
      # puts "ALICE::: #{OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.verify(alice)}"
      opts[:handlers] = {
        # Should be done in a better way
        :pre_rackup => lambda do
          EM.next_tick do
          # Thread.new do
            OmfCommon.init(@@config[:operationMode], :communication => {:url => "xmpp://#{@@xmpp[:user]}:#{@@xmpp[:password]}@#{@@xmpp[:server]}", :auth => {}}) do |el|
            # OmfCommon.init(@@config[:operationMode], :communication => {:url => "amqp://testServer", :auth => {}}) do |el|
             puts "Connected to the XMPP."
            end
          end
        end,
        :pre_parse => lambda do |p, options|
          p.on("--test-load-am", "Load an AM configuration for testing") do |n| options[:load_test_am] = true end
          p.separator ""
          p.separator "Database options:"
          p.on("--database URL", "Database's URL [#{options[:database]}]") do |u| options[:database] = u end
          p.separator ""
        end,
        :pre_run => lambda do |opts|
          puts "OPTS: #{opts.inspect}"
          init_logger()
          check_dependencies()
          load_trusted_cert_roots()
          init_db(opts)
          init_am_manager(opts)
          load_test_am(opts) if opts[:load_test_am]
          # EM.next_tick do
          #   OmfCommon.init(@@config[:operationMode], :communication => {:url => "amqp://testServer", :auth => {}}) do |el|
          #     puts "Connected to the XMPP."
          #   end
          # end
        end
      }


      # Thin::Logging.debug = false
      require 'omf_common/thin/runner'
      OMF::Common::Thin::Runner.new(ARGV, opts).run!
    end

  end # class
end # module

# Configure the web server
#
rpc = OMF::SFA::AM::AMServer.rpc_config
xmpp = OMF::SFA::AM::AMServer.xmpp_config

opts = {
  :app_name => 'am_server',
  :port => rpc[:port] || 8001,
  :environment => @@config[:operationMode],
  :ssl =>
  {
    :cert_file => File.expand_path(rpc[:ssl][:cert_chain_file]),
    :key_file => File.expand_path(rpc[:ssl][:private_key_file]),
    :verify_peer => true,
  },
  :xmpp =>
  {
    :auth => xmpp[:auth],
  },
  :database => "#{@@config[:database]}",
  :rackup => File.dirname(__FILE__) + '/config.ru',
}
if @@config[:mapping_submodule]
  opts[:mapping_submodule] = {}
  opts[:mapping_submodule][:require] =  @@config[:mapping_submodule][:require]
  opts[:mapping_submodule][:constructor] =  @@config[:mapping_submodule][:constructor]
end
if @@config[:am_liaison]
  opts[:am_liaison] = {}
  opts[:am_liaison][:require] = @@config[:am_liaison][:require]
  opts[:am_liaison][:constructor] =  @@config[:am_liaison][:constructor]
end
OMF::SFA::AM::AMServer.new.run(opts)
