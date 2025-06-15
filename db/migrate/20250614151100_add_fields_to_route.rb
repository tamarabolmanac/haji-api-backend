class AddFieldsToRoute < ActiveRecord::Migration[8.0]
  def change
    add_column :hike_routes, :duration, :integer
    add_column :hike_routes, :difficulty, :string
  end
end
