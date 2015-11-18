Sequel.migration do
  up do
    create_table(:usrp_ethernet_devices) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade

      String  :operating_frequency
      String  :cpu_model
      String  :antennas
      String  :base_model
      String  :vendor
      String :number_of_antennas
    end
    alter_table(:interfaces) do
      add_foreign_key :usrp_ethernet_device_id, :usrp_ethernet_devices, :on_delete => :cascade
    end
  end

  down do
    drop_table(:usrp_usb_devices)
    drop_column :interfaces, :usrp_ethernet_device_id
  end
end