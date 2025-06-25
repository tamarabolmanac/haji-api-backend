class User < ApplicationRecord
  has_secure_password
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, allow_nil: true
  validates :password_confirmation, presence: true, if: -> { password.present? }
  validates :name, presence: true
  validates :role, presence: true
  validates :city, presence: true
  validates :country, presence: true
end
