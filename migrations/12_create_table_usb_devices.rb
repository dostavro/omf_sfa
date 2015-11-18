Sequel.migration do
  up do
    create_table(:usb_devices) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade
      foreign_key :node_id, :nodes, :on_delete => :set_null

      String :base_model
      String :vendor
      String :number_of_antennas
      Integer :usb_version
    end
  end

  down do
    drop_table(:usb_devices)
  end
end