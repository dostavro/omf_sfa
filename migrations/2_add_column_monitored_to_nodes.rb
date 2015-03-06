Sequel.migration do

  up do
    add_column :nodes, :monitored, TrueClass
  end

  down do
    drop_column :nodes, :monitored
  end
end
