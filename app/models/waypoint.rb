# A place marker on a hike route's map (viewpoint, spring, parking, …).
# Owner-placed; everyone viewing the route sees them.
class Waypoint < ApplicationRecord
  belongs_to :hike_route

  # Marker kinds. The shared ids reuse the route tag vocabulary/icons on the
  # frontend; a few (izvor, pecina, opasnost, voda) are waypoint-only.
  ALLOWED_KINDS = %w[
    vidikovac vodopad reka jezero izvor voda odmor suma
    parking hrana kafic pecina opasnost
  ].freeze

  validates :kind, presence: true, inclusion: { in: ALLOWED_KINDS }
  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :label, length: { maximum: 120 }

  def as_marker_json
    { id: id, kind: kind, label: label, lat: latitude, lng: longitude }
  end
end
