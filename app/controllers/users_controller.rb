class UsersController < ApiController
  include Utils
  before_action :authenticate_user, only: [:user_data, :update, :index, :follow, :unfollow, :request_deletion]
  before_action :optional_auth_for_show, only: [:show]

  def show
    user = User.find_by(id: params[:id])
    unless user
      render json: { error: "Korisnik nije pronađen." }, status: :not_found
      return
    end

    routes = user.hike_routes
                 .left_joins(:points)
                 .select('hike_routes.*, COUNT(points.id) AS points_count')
                 .group('hike_routes.id')
                 .map do |route|
      {
        id: route.id,
        title: route.title,
        description: route.description,
        distance: route.distance,
        duration: route.duration,
        points_count: route.points_count.to_i
      }
    end

    total_distance = user.total_distance.to_f
    total_duration = user.total_duration.to_i

    payload = {
      id: user.id,
      name: user.name,
      city: user.city,
      country: user.country,
      avatar_url: avatar_url_for(user),
      routes: routes,
      total_distance: total_distance,
      total_duration: total_duration,
      routes_count: routes.length
    }
    payload[:is_me] = (@current_user && @current_user.id == user.id)
    payload[:is_following] = (@current_user && @current_user.following.exists?(user.id)) if @current_user

    render json: payload, status: :ok
  end

  def index
    users = User.order(:name)

    payload = users.map do |u|
      {
        id: u.id,
        name: u.name,
        email: u.email,
        city: u.city,
        country: u.country,
        avatar_url: avatar_url_for(u),
        is_me: u.id == @current_user.id,
        is_following: @current_user.following.exists?(u.id)
      }
    end

    render json: payload, status: :ok
  end

  def user_data
    routes_count = @current_user.hike_routes.count

    user_data = {
      id: @current_user.id,
      name: @current_user.name,
      email: @current_user.email,
      role: @current_user.role,
      city: @current_user.city,
      country: @current_user.country,
      avatar_url: avatar_url_for(@current_user),
      total_distance: @current_user.total_distance.to_f,
      total_duration: @current_user.total_duration.to_i,
      routes_count: routes_count
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

  def follow
    target = User.find(params[:id])

    if target == @current_user
      render json: { message: "Ne možete pratiti sami sebe." }, status: :unprocessable_entity
      return
    end

    @current_user.follow(target)

    render json: {
      message: "Sada pratite korisnika.",
      user_id: target.id
    }, status: :ok
  end

  def unfollow
    target = User.find(params[:id])

    @current_user.unfollow(target)

    render json: {
      message: "Više ne pratite ovog korisnika.",
      user_id: target.id
    }, status: :ok
  end

  def block
    target = User.find(params[:id])
    if target.id == @current_user.id
      render json: { message: "Ne možete blokirati sebe." }, status: :unprocessable_entity
      return
    end

    @current_user.blocks_made.find_or_create_by!(blocked: target)
    # Prekini eventualno međusobno praćenje
    @current_user.unfollow(target) if @current_user.respond_to?(:unfollow)
    target.unfollow(@current_user) if target.respond_to?(:unfollow)

    render json: { message: "Korisnik je blokiran.", user_id: target.id }, status: :ok
  rescue ActiveRecord::RecordNotUnique
    render json: { message: "Korisnik je već blokiran.", user_id: params[:id].to_i }, status: :ok
  end

  def unblock
    target = User.find(params[:id])
    @current_user.blocks_made.where(blocked: target).destroy_all
    render json: { message: "Korisnik je odblokiran.", user_id: target.id }, status: :ok
  end

  def request_deletion
    unless @current_user.id == params[:id].to_i
      render json: { error: "Nemate dozvolu za ovu akciju." }, status: :forbidden
      return
    end

    @current_user.send_deletion_confirmation_email!
    render json: { message: "Email za potvrdu brisanja naloga je poslat." }, status: :ok
  end

  def confirm_deletion
    user = User.find_signed(params[:token], purpose: :account_deletion)

    if user.present?
      user.destroy!
      render json: { message: "Nalog je uspešno obrisan." }, status: :ok
    else
      render json: { message: "Nevalidan ili istekao link." }, status: :unprocessable_entity
    end
  end

  private

  def optional_auth_for_show
    authenticate_token
  end

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
