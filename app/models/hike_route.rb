class HikeRoute < ApplicationRecord
  belongs_to :user
  has_many_attached :images
  has_many :points, dependent: :destroy
  
  # Invalidate cache when route is updated
  after_update :invalidate_cache
  
  private
  
  def invalidate_cache
    Rails.cache.delete("hike:#{id}")
    Rails.logger.info "Cache invalidated for route #{id} due to route update"
  end
end