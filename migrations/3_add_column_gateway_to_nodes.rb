Sequel.migration do

  up do
    add_column :nodes, :gateway, String
  end

  down do
    drop_column :nodes, :gateway
  end
end
