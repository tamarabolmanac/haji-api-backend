class AddStatusToHikeRoutes < ActiveRecord::Migration[8.0]
  def change
    add_column :hike_routes, :status, :string, default: "draft", null: false
  end
end

