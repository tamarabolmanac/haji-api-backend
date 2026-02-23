class UsersController < ApiController
  include Utils
  before_action :authenticate_user, only: [:user_data, :update]

  def user_data
    user_data = {
      id: @current_user.id,
      name: @current_user.name,
      email: @current_user.email,
      role: @current_user.role,
      city: @current_user.city,
      country: @current_user.country,
      avatar_url: avatar_url_for(@current_user)
    }
    render json: user_data, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  def update
    # Update basic attributes
    if @current_user.update(user_update_params)
      # Attach avatar if provided
      if params[:avatar].present?
        @current_user.avatar.attach(params[:avatar])
      end

      render json: {
        id: @current_user.id,
        name: @current_user.name,
        email: @current_user.email,
        role: @current_user.role,
        city: @current_user.city,
        country: @current_user.country,
        avatar_url: avatar_url_for(@current_user)
      }, status: :ok
    else
      render json: { message: 'Validation failed', errors: @current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def forgot_password
    @user = User.find_by(email: params[:email])
    if @user
      @user.send_password_reset_email!
      render json: { message: "Email za reset lozinke je poslat." }, status: :ok
    else
      render json: { message: "Korisnik sa unetim emailom nije pronadjen." }, status: :not_found
    end
  end

  def reset_password
    @user = User.find_signed(params[:token], purpose: :password_reset)
    
    if @user.present?
      if @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
        render json: { message: "Lozinka je uspešno promenjena." }, status: :ok
      else
        render json: { message: @user.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    else
      render json: { message: "Nevalidan ili istekao token." }, status: :unprocessable_entity
    end
  end

  def confirm
    @user = User.find_signed(params[:token])

    if @user.present? && @user.confirm!
      render json: { message: "Your account has been confirmed." }, status: :ok
    else
      render json: { message: "Invalid token." }, status: :unprocessable_entity
    end
  end

  def online
    ids = OnlineTracker.list
    users = User.where(id: ids)
    payload = users.map { |u| { id: u.id, name: u.name, avatar_url: avatar_url_for(u) } }
    render json: payload
  end

  private

  def user_update_params
    params.permit(:name, :city, :country)
  end

  def avatar_url_for(user)
    return nil unless user.avatar.attached?
    begin
      s3 = Aws::S3::Resource.new(
        access_key_id: ENV['R2_ACCESS_KEY'],
        secret_access_key: ENV['R2_SECRET_KEY'],
        endpoint: ENV['R2_ENDPOINT'],
        region: ENV['R2_REGION'] || 'auto'
      )
      obj = s3.bucket(ENV['R2_BUCKET_NAME']).object(user.avatar.blob.key)
      return obj.presigned_url(:get, expires_in: 15 * 60)
    rescue => _e
      # Fallback to Rails blob URL
      path = Rails.application.routes.url_helpers.rails_blob_path(user.avatar, only_path: true)
      base = ENV['PUBLIC_API_BASE_URL'].presence || (Rails.env.production? ? 'https://api.hajki.com' : request.base_url)
      return "#{base}#{path}"
    end
  end
end
