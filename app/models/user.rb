class User < ApplicationRecord
  CONFIRMATION_TOKEN_EXPIRATION = 10.minutes
  PASSWORD_RESET_TOKEN_EXPIRATION = 2.hours
  MAILER_FROM_EMAIL = 'info@hajki.com'

  has_secure_password
  has_many :hike_routes, dependent: :destroy
  has_one_attached :avatar
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, allow_nil: true
  validates :password_confirmation, presence: true, if: -> { password.present? }
  validates :name, presence: true
  validates :role, presence: true
  validates :city, presence: true
  validates :country, presence: true

  def send_confirmation_email!
    UserMailer.confirmation(self, generate_confirmation_token).deliver_later
  end

  def send_password_reset_email!
    UserMailer.reset_password(self, generate_password_reset_token).deliver_later
  end

  def confirm!
    update!(email_confirmed_at: Time.current)
  end

  def confirmed?
    email_confirmed_at.present?
  end

  private

  def generate_confirmation_token
    signed_id(expires_in: CONFIRMATION_TOKEN_EXPIRATION)
  end

  def generate_password_reset_token
    signed_id(purpose: :password_reset, expires_in: PASSWORD_RESET_TOKEN_EXPIRATION)
  end
end
