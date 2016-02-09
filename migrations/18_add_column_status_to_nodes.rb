Sequel.migration do
  up do
    add_column :nodes, :status, String
  end

  down do
    drop_column :nodes, :status
  end
end

