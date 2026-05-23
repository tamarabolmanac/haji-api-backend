class AddStatsToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :total_distance, :decimal, precision: 10, scale: 2, default: 0, null: false
    add_column :users, :total_duration, :integer, default: 0, null: false

    # Retroaktivno izracunaj za sve korisnike
    User.find_each do |user|
      routes = user.hike_routes.includes(:points)
      total_distance = routes.sum(&:display_distance).to_f.round(2)
      total_duration = routes.sum(&:display_duration).to_i

      user.update_columns(
        total_distance: total_distance,
        total_duration: total_duration
      )
    end
  end

  def down
    remove_column :users, :total_distance
    remove_column :users, :total_duration
  end
end
