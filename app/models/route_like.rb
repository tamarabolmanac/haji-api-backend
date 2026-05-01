class RouteLike < ApplicationRecord
  belongs_to :user
  belongs_to :hike_route

  validates :user_id, uniqueness: { scope: :hike_route_id }
end
