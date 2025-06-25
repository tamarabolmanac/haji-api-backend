class AuthController < ApplicationController
  include Utils
  skip_before_action :verify_authenticity_token

  def register
    puts params
    user = User.new(user_params)
    
    if user.save
      token = generate_token(user.id)
      render json: { 
        status: 200, 
        message: "User registered successfully",
        token: token
      }
    else
      render json: { 
        status: 400, 
        message: user.errors.full_messages.join(', ')
      }
    end
  end

  def login
    user = User.find_by(email: login_params[:email])
    pp "Test login"
    pp user
    if user && user.authenticate(login_params[:password])
      pp "Render success"
      token = generate_token(user)
      render json: { 
        status: 200, 
        message: "User logged in successfully",
        token: token
      }
    else
      pp 'Render fail'
      render json: { 
        status: 401, 
        message: "Invalid credentials"
      }
    end
  end

  private

  def user_params
    params.require(:auth).permit(:name, :email, :password, :password_confirmation, :role, :city, :country)
  rescue => e
    Rails.logger.error "Error in user_params: #{e.message}"
    params.permit(:name, :email, :password, :password_confirmation, :role, :city, :country)
  end

  def login_params
    params.require(:auth).permit(:email, :password)
  rescue => e
    Rails.logger.error "Error in login_params: #{e.message}"
    params.permit(:email, :password)
  end

  def generate_token(user)
    { user: { user_id: user.id, username: user.name, email: user.email}, token: JwtAuthenticator.new.encode(user) }
  end
end
