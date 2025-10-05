class Point < ApplicationRecord
  belongs_to :hike_route
  belongs_to :user, optional: true
  
  validates :lat, :lng, presence: true
  validates :lat, inclusion: { in: -90..90 }
  validates :lng, inclusion: { in: -180..180 }
end
