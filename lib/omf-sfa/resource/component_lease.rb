
module OMF::SFA::Resource

  class ComponentLease
    include DataMapper::Resource

    belongs_to :lease, :model => 'Lease', :key => true
    belongs_to :component, :model => 'OComponent', :key => true
  end
end
