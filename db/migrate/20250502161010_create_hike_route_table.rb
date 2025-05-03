class CreateHikeRouteTable < ActiveRecord::Migration[8.0]
  def change
    create_table :hike_routes do |t|
      t.integer "title"
      t.text "description"
      
      t.timestamps
    end
  end
end
