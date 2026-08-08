class AddActivityTypeToHikeRoutes < ActiveRecord::Migration[8.0]
  def change
    # "hike" ili "bike" — tip aktivnosti rute. Postojeće rute dobijaju "hike".
    add_column :hike_routes, :activity_type, :string, default: "hike", null: false
  end
end
