class AddAdditionalFieldsToHikeRoutes < ActiveRecord::Migration[8.0]
  def change
    add_column :hike_routes, :distance, :decimal, precision: 10, scale: 2
    add_column :hike_routes, :location_latitude, :decimal, precision: 10, scale: 6
    add_column :hike_routes, :location_longitude, :decimal, precision: 10, scale: 6
    add_column :hike_routes, :best_time_to_visit, :string
  end
end
