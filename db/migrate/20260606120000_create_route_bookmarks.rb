class CreateRouteBookmarks < ActiveRecord::Migration[8.0]
  def change
    create_table :route_bookmarks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :hike_route, null: false, foreign_key: true
      t.timestamps
    end

    add_index :route_bookmarks, [:user_id, :hike_route_id], unique: true, name: "index_route_bookmarks_on_user_id_and_hike_route_id"
  end
end
