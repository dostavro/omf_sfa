require 'omf_sfa'

module OMF::SFA
  module Model; end
end

require 'omf-sfa/models/sfa_base'
Sequel::Model.plugin :json_serializer
Dir['./lib/omf-sfa/models/*.rb'].each{|f| require f}
