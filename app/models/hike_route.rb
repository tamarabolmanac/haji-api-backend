class HikeRoute < ApplicationRecord
  belongs_to :user
  has_many_attached :images
  has_many :points, dependent: :destroy
  
  # Invalidate cache when route is updated
  after_update :invalidate_cache
  
  # Calculate distance from points using Haversine formula
  def calculated_distance
    return distance if points.count < 2
    
    total_distance = 0
    ordered_points = points.order(:timestamp)
    
    (1...ordered_points.count).each do |i|
      prev_point = ordered_points[i - 1]
      curr_point = ordered_points[i]
      total_distance += haversine_distance(prev_point, curr_point)
    end
    
    total_distance.round(2)
  end
  
  # Calculate duration from points (in minutes)
  def calculated_duration
    return duration if points.count < 2
    
    ordered_points = points.order(:timestamp)
    first_point = ordered_points.first
    last_point = ordered_points.last
    
    # Calculate duration in minutes
    duration_seconds = last_point.timestamp - first_point.timestamp
    (duration_seconds / 60).round
  end
  
  # Get the appropriate distance (calculated or stored)
  def display_distance
    points.count >= 2 ? calculated_distance : distance
  end
  
  # Get the appropriate duration (calculated or stored)
  def display_duration
    points.count >= 2 ? calculated_duration : duration
  end
  
  private
  
  def invalidate_cache
    Rails.cache.delete("hike:#{id}")
    Rails.logger.info "Cache invalidated for route #{id} due to route update"
  end
  
  # Haversine formula to calculate distance between two points
  def haversine_distance(point1, point2)
    rad_per_deg = Math::PI / 180  # PI / 180
    rkm = 6371                    # Earth radius in kilometers
    
    lat1_rad = point1.lat * rad_per_deg
    lat2_rad = point2.lat * rad_per_deg
    delta_lat_rad = (point2.lat - point1.lat) * rad_per_deg
    delta_lon_rad = (point2.lng - point1.lng) * rad_per_deg
    
    a = Math.sin(delta_lat_rad / 2)**2 + 
        Math.cos(lat1_rad) * Math.cos(lat2_rad) * 
        Math.sin(delta_lon_rad / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    
    rkm * c # Distance in kilometers
  end
end