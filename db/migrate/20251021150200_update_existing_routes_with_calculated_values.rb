class UpdateExistingRoutesWithCalculatedValues < ActiveRecord::Migration[7.0]
  def up
    say "Updating existing routes with calculated distance and duration values..."
    
    HikeRoute.includes(:points).find_each do |route|
      if route.points.count >= 2
        calculated_distance = route.calculated_distance
        calculated_duration = route.calculated_duration
        
        route.update_columns(
          distance: calculated_distance,
          duration: calculated_duration
        )
        
        say "Updated route #{route.id}: distance=#{calculated_distance}km, duration=#{calculated_duration}min"
      else
        say "Skipped route #{route.id}: less than 2 points"
      end
    end
    
    say "Finished updating existing routes"
  end

  def down
    say "This migration cannot be reversed as it updates calculated values"
    # We don't reverse this as the calculated values are the correct ones
  end
end
