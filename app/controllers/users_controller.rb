class UsersController < ApiController
  include Utils
  before_action :authenticate_user, only: [:user_data]

  def user_data
    user_data = {
      id: @current_user.id,
      name: @current_user.name,
      email: @current_user.email,
      role: @current_user.role,
      city: @current_user.city,
      country: @current_user.country
    }
    render json: user_data, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  def confirm
    @user = User.find_signed(params[:token])

    if @user.present?
      @user.confirm!
      render json: { message: "Your account has been confirmed." }, status: :ok
    else
      render json: { message: "Invalid token." }, status: :unprocessable_entity
    end
  end
end
