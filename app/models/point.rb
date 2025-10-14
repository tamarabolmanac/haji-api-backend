class Point < ApplicationRecord
  belongs_to :hike_route
  belongs_to :user, optional: true
  
  validates :lat, :lng, presence: true
  validates :lat, inclusion: { in: -90..90 }
  validates :lng, inclusion: { in: -180..180 }
  
  after_save :invalidate_route_cache
  after_destroy :invalidate_route_cache
  
  private
  
  def invalidate_route_cache
    Rails.cache.delete("hike:#{hike_route_id}")
    Rails.logger.info "Cache invalidated for route #{hike_route_id} due to point change"
  end
end
