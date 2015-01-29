Sequel.migration do
  up do
    add_column :leases, :client_id, String
  end

  down do
    drop_column :leases, :client_id
  end
end
