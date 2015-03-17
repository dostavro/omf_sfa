Sequel.migration do
  up do
    add_column :locations, :altitude, Float
    drop_column :locations, :latitude
    drop_column :locations, :longitude
    add_column :locations, :latitude, Float
    add_column :locations, :longitude, Float
    drop_column :locations, :node_id
    add_column :nodes, :location_id, Integer
  end

  down do
    drop_column :locations, :altitude
    drop_column :nodes, :location_id
    add_column :locations, :node_id, Integer
  end
end
