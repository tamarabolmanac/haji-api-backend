class AddElevationToPoints < ActiveRecord::Migration[8.0]
  def change
    add_column :points, :elevation, :float
  end
end
