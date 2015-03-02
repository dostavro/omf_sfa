Sequel.migration do
  up do
    create_table(:wimax_base_stations) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade

      String :base_model
      String :vendor
      String :band
      String :vlan
      String :mode
      String :center_frequency
      String :channel_bandwidth
      Integer :number_of_antennas
    end
  end

  down do
    drop_table(:wimax_base_stations)
  end
end