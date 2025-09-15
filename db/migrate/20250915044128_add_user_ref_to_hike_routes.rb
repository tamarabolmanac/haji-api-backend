class AddUserRefToHikeRoutes < ActiveRecord::Migration[8.0]
  def change
        add_reference :hike_routes, :user, null: true, foreign_key: true
  end
end
