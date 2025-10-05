class UpdatePointsTable < ActiveRecord::Migration[7.0]
  def change
    # Remove old foreign key if exists
    remove_foreign_key :points, :hike_routes if foreign_key_exists?(:points, :hike_routes)

    # Remove old column if exists
    remove_column :points, :hike_routes_id if column_exists?(:points, :hike_routes_id)

    # Add correct foreign key reference safely
    add_reference :points, :hike_route, null: true, foreign_key: true unless column_exists?(:points, :hike_route_id)

    # Add user reference
    add_reference :points, :user, null: true, foreign_key: true unless column_exists?(:points, :user_id)

    # Add accuracy column
    add_column :points, :accuracy, :float unless column_exists?(:points, :accuracy)

    # Ensure timestamp column exists
    add_column :points, :timestamp, :datetime unless column_exists?(:points, :timestamp)
  end
end
