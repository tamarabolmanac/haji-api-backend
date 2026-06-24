class AddTagsToHikeRoutes < ActiveRecord::Migration[8.0]
  def change
    add_column :hike_routes, :tags, :string, array: true, default: [], null: false
    add_index :hike_routes, :tags, using: :gin
  end
end
