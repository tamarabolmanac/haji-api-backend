class HikeRoute < ApplicationRecord
  belongs_to :user
  has_many_attached :images
  has_many :points, dependent: :delete_all
  has_many :route_likes, dependent: :delete_all
  has_many :route_bookmarks, dependent: :delete_all
  has_many :liked_by_users, through: :route_likes, source: :user
  
  STATUSES = %w[draft tracking finalized].freeze

  # Place characteristics a route can be tagged with. Keys are stored; the
  # frontend maps them to localized labels + icons.
  ALLOWED_TAGS = %w[
    kafic komarci guzva vodopad reka jezero vidikovac odmor
    suma dostupno vetrovito parking hrana blato insekti
  ].freeze

  before_validation :normalize_tags
  validate :tags_must_be_allowed

  # Invalidate cache when route is updated
  after_update :invalidate_cache
  # Update user stats when route is finalized or deleted
  after_save :update_user_stats, if: :saved_change_to_status?
  after_destroy :update_user_stats
  
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
  
  # Get the appropriate distance (stored or calculated as fallback)
  def display_distance
    # If we have stored distance and at least 2 points, use stored value
    if distance.present? && points.count >= 2
      distance
    elsif points.count >= 2
      # Fallback to calculation if stored value is missing
      calculated_distance
    else
      # Use manually entered distance for routes with < 2 points
      distance || 0
    end
  end
  
  # Get the appropriate duration (stored or calculated as fallback)
  def display_duration
    # If we have stored duration and at least 2 points, use stored value
    if duration.present? && points.count >= 2
      duration
    elsif points.count >= 2
      # Fallback to calculation if stored value is missing
      calculated_duration
    else
      # Use manually entered duration for routes with < 2 points
      duration || 0
    end
  end
  
  # Zaključava rutu kao finalized. Ako ima >= 2 tačke, usput izračuna
  # distance/duration iz tačaka; u suprotnom samo postavi status.
  def finalize_route!
    if points.count >= 2
      update_columns(
        distance: calculated_distance,
        duration: calculated_duration,
        status: "finalized"
      )
    else
      update_column(:status, "finalized")
    end
  end

  def self.new_route_for_user(user, formatted_time)
    user.hike_routes.create!(
      title: "Nova ruta #{formatted_time}",
      description: "",
      difficulty: "medium",
      duration: 0,
      distance: 0,
      status: "tracking"
    )
  end
  
  private

  def normalize_tags
    self.tags = Array(tags).map { |t| t.to_s.strip.downcase }.reject(&:blank?).uniq
  end

  def tags_must_be_allowed
    invalid = tags - ALLOWED_TAGS
    errors.add(:tags, "sadrži nepoznate vrednosti: #{invalid.join(', ')}") if invalid.any?
  end

  def invalidate_cache
    Rails.cache.delete("hike:#{id}")
  end

  def update_user_stats
    return unless user
    user.update_columns(
      total_distance: user.hike_routes.sum(:distance).to_f.round(2),
      total_duration: user.hike_routes.sum(:duration).to_i
    )
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