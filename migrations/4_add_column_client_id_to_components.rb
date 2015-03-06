Sequel.migration do
  up do
    add_column :components, :client_id, String
  end

  down do
    drop_column :components, :client_id
  end
end
