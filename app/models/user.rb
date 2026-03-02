class User < ApplicationRecord
  CONFIRMATION_TOKEN_EXPIRATION = 10.minutes
  PASSWORD_RESET_TOKEN_EXPIRATION = 2.hours
  MAILER_FROM_EMAIL = 'info@hajki.com'

  has_secure_password
  has_many :hike_routes, dependent: :destroy
  has_one_attached :avatar
  has_many :active_follows, class_name: "UserFollow", foreign_key: :follower_id, dependent: :destroy
  has_many :following, through: :active_follows, source: :followed
  has_many :passive_follows, class_name: "UserFollow", foreign_key: :followed_id, dependent: :destroy
  has_many :followers, through: :passive_follows, source: :follower
  
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

  def follow(other_user)
    return if other_user == self
    following << other_user unless following.exists?(other_user.id)
  end

  def unfollow(other_user)
    active_follows.where(followed: other_user).destroy_all
  end

  def following?(other_user)
    following.exists?(other_user.id)
  end

  private

  def generate_confirmation_token
    signed_id(expires_in: CONFIRMATION_TOKEN_EXPIRATION)
  end

  def generate_password_reset_token
    signed_id(purpose: :password_reset, expires_in: PASSWORD_RESET_TOKEN_EXPIRATION)
  end
end
