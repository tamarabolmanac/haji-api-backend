class UpdatePointsTable < ActiveRecord::Migration[8.0]
  def change
    # Remove old foreign key if it exists
    if foreign_key_exists?(:points, :hike_routes)
      remove_foreign_key :points, :hike_routes
    end
    
    # Remove old reference column if it exists
    if column_exists?(:points, :hike_routes_id)
      remove_column :points, :hike_routes_id
    end
    
    # Add correct foreign key reference
    unless column_exists?(:points, :hike_route_id)
      add_reference :points, :hike_route, null: false, foreign_key: true
    end
    
    # Add user reference
    unless column_exists?(:points, :user_id)
      add_reference :points, :user, null: true, foreign_key: true
    end
    
    # Add accuracy column
    unless column_exists?(:points, :accuracy)
      add_column :points, :accuracy, :float
    end
    
    # Ensure timestamp column exists and is datetime
    unless column_exists?(:points, :timestamp)
      add_column :points, :timestamp, :datetime
    end
  end
end
