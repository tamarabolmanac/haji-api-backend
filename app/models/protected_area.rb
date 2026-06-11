class ProtectedArea < ApplicationRecord
  has_one_attached :image

  AREA_TYPES = %w[national_park nature_park mountain].freeze

  validates :name, presence: true, uniqueness: true
  validates :area_type, inclusion: { in: AREA_TYPES }
end
