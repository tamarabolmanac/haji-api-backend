class CreateWaypoints < ActiveRecord::Migration[8.0]
  def change
    create_table :waypoints do |t|
      t.references :hike_route, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :label
      t.float :latitude, null: false
      t.float :longitude, null: false

      t.timestamps
    end
  end
end
