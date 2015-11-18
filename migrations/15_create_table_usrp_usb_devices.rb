Sequel.migration do
  up do
    create_table(:usrp_usb_devices) do
      foreign_key :id, :resources, :primary_key => true, :on_delete => :cascade

      String  :operating_frequency
      String  :cpu_model
      String  :antennas
    end
  end

  down do
    drop_table(:usrp_usb_devices)
  end
end