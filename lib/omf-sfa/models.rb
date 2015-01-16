require 'omf_sfa'

module OMF::SFA
  module Model; end
end

require 'omf-sfa/models/sfa_base'
Sequel::Model.plugin :json_serializer
Sequel.default_timezone = :utc
Dir['./lib/omf-sfa/models/*.rb'].each{|f| require f}
