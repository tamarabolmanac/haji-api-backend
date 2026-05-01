class CreateRouteLikes < ActiveRecord::Migration[8.0]
  def change
    create_table :route_likes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :hike_route, null: false, foreign_key: true

      t.timestamps
    end

    add_index :route_likes, [:user_id, :hike_route_id], unique: true
  end
end
