require 'omf-sfa/models/component'

module OMF::SFA::Model
  class Channel < Component

    sfa_class 'channel', :namespace => :ol

    sfa :frequency, :attribute => true
  end
end
