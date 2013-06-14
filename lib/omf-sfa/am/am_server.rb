require 'rubygems'
require 'rack'
require 'rack/showexceptions'
require 'thin'
require 'dm-migrations'
require 'omf_common/lobject'
require 'omf_common/load_yaml'

require 'omf-sfa/am/am_runner'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/am_scheduler'
require 'omf-sfa/am/am_liaison'
require 'omf-sfa/am/am-xmpp/am_xmpp'


module OMF::SFA::AM

  class AMServer
    # Don't use LObject as we haven't initialized the logging system yet. Happens in 'init_logger'
    include OMF::Common::Loggable
    extend OMF::Common::Loggable

    @@config = OMF::Common::YAML.load('omf-sfa-am', :path => [File.dirname(__FILE__) + '/../../../etc/omf-sfa'])[:omf_sfa_am]
    @@rpc = @@config[:endpoints].select { |v| v[:type] == 'xmlrpc' }.first

    def self.rpc_config
      @@rpc
    end

    def init_logger
      OMF::Common::Loggable.init_log 'am_server', :searchPath => File.join(File.dirname(__FILE__), 'am_server')
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
          trusted_cert = OpenSSL::X509::Certificate.new(File.read(fne))
          OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.add_cert(trusted_cert)
        else
          warn "Can't find trusted root cert '#{trusted_roots}/#{fne}'"
        end
      end
    end

    def init_data_mapper(options)
      #@logger = OMF::Common::Loggable::_logger('am_server')
      #OMF::Common::Loggable.debug "options: #{options}"
      debug "options: #{options}"

      # Configure the data store
      #
      DataMapper::Logger.new(options[:dm_log] || $stdout, :info)
      #DataMapper::Logger.new($stdout, :info)

      #DataMapper.setup(:default, config[:data_mapper] || {:adapter => 'yaml', :path => '/tmp/am_test2'})
      DataMapper.setup(:default, options[:dm_db])

      require 'omf-sfa/resource'
      DataMapper::Model.raise_on_save_failure = true
      DataMapper.finalize

      # require  'dm-migrations'
      # DataMapper.auto_migrate!

      DataMapper.auto_upgrade! if options[:dm_auto_upgrade]
      load_test_am(options) if options[:load_test_am]
    end


    def load_test_am(options)
      require  'dm-migrations'
      DataMapper.auto_migrate!

      am = OMF::SFA::AM::AMManager.new(OMF::SFA::AM::AMScheduler.new)
      options[:am][:manager] = am

      require 'omf-sfa/resource/oaccount'
      #account = am.find_or_create_account(:name => 'foo')
      account = OMF::SFA::Resource::OAccount.new(:name => 'foo')

      require 'omf-sfa/resource/node'
      nodes = []
      3.times do |i|
        name = "node#{i}"
        uuid = UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, name)
        nodes << (n = OMF::SFA::Resource::Node.create(:name => name, :uuid => uuid))
        am.manage_resource(n)
      end
      #  am.find_resource 'n1', :requester_account => account
      #nodes.first.leases << OMF::SFA::Resource::OLease.create(:name => 'l1', :valid_from => Time.now, :valid_until => Time.now + 3600)
      #nodes.first.leases << OMF::SFA::Resource::OLease.create(:name => 'l2', :valid_from => Time.now + 3600, :valid_until => Time.now + 7200)
      #nodes.first.save

      #nodes.last.leases << OMF::SFA::Resource::OLease.create(:name => 'l1', :valid_from => Time.now, :valid_until => Time.now + 3600)
      #nodes.last.save
    end

    def run(opts)
      # alice = OpenSSL::X509::Certificate.new(File.read('/Users/max/.gcf/alice-cert.pem'))
      # puts "ALICE::: #{OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.verify(alice)}"
      opts[:handlers] = {
        # Should be done in a better way
        :pre_rackup => lambda do
          #Thread.new do
          #  begin
          #    sleep 3
          EM.next_tick do
            OmfCommon.init(:development, :communication => {:url => 'xmpp://am_liaison:pw@localhost', :auth => {}}) do |el|
              #opts[:liaison] = OMF::SFA::AM::AMLiaison.new
              puts "Connected to the XMPP."
            end
          end
          #  rescue Exception => ex
          #    puts "ERROR: #{ex}"
          #    puts "\t#{ex.backtrace.join("\n\t")}"
          #  end
          #end
        end,
        :pre_parse => lambda do |p, options|
          p.on("--test-load-am", "Load an AM configuration for testing") do |n| options[:load_test_am] = true end
          p.separator ""
          p.separator "Datamapper options:"
          p.on("--dm-db URL", "Datamapper database [#{options[:dm_db]}]") do |u| options[:dm_db] = u end
          p.on("--dm-log FILE", "Datamapper log file [#{options[:dm_log]}]") do |n| options[:dm_log] = n end
          p.on("--dm-auto-upgrade", "Run Datamapper's auto upgrade") do |n| options[:dm_auto_upgrade] = true end
          p.separator ""
        end,
        :pre_run => lambda do |opts|
          init_logger()
          load_trusted_cert_roots()
          init_data_mapper(opts)
          check_dependencies()
          #EM.next_tick do
          #  #OmfCommon::Comm::XMPP::Communicator.init(:url => 'xmpp://am_liaison:pw@localhost') do
          #  OmfCommon.init(:development, :communication => {:url => 'xmpp://am_liaison:pw@localhost'}) do
          #    opts[:liaison] = OMF::SFA::AM::AMLiaison.new
          #    #OmfCommon.comm.on_connected do |comm|
          #    #  puts "Connected!"
          #    #end
          #  end
          #end
        end
      }

      #Thin::Logging.debug = true
      require 'omf_common/thin/runner'
      OMF::Common::Thin::Runner.new(ARGV, opts).run!
    end

  end # class
end # module

# Configure the web server
#
rpc = OMF::SFA::AM::AMServer.rpc_config()
@opts = {
  :app_name => 'am_server',
  :port => 8001,
  :am =>
  {
    #:manager => lambda { OMF::SFA::AM::AMManager.new(OMF::SFA::AM::AMScheduler.new) },
    #:liaison => lambda { OMF::SFA::AM::AMLiaison.new },
    #:r_controller => lambda { OMF::SFA::AM::XMPP::AMController.new }
  },
  :ssl =>
  {
    :cert_file => File.expand_path(rpc[:ssl][:cert_chain_file]),
    :key_file => File.expand_path(rpc[:ssl][:private_key_file]),
    :verify_peer => true
    #:verify_peer => false
  },
    #:log => '/tmp/am_server.log',
    :dm_db => 'sqlite:///tmp/am_test.db',
    :dm_log => '/tmp/am_server-dm.log',
    :rackup => File.dirname(__FILE__) + '/config.ru',
}
  OMF::SFA::AM::AMServer.new.run(@opts)



