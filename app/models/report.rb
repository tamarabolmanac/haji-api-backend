class Report < ApplicationRecord
  REASONS = %w[spam neprikladan_sadrzaj uznemiravanje netacne_informacije ostalo].freeze
  STATUSES = %w[pending reviewed dismissed].freeze

  belongs_to :reporter, class_name: "User"
  belongs_to :hike_route, optional: true
  belongs_to :reported_user, class_name: "User", optional: true

  validates :reason, presence: true
  validate :must_reference_something

  private

  def must_reference_something
    if hike_route_id.blank? && reported_user_id.blank?
      errors.add(:base, "Prijava mora da se odnosi na rutu ili korisnika.")
    end
  end
end
