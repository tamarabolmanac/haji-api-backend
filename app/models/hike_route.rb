class HikeRoute < ApplicationRecord
  belongs_to :user
  has_many_attached :images
  has_many :points, dependent: :destroy
end