class AuthController < ApplicationController
  include Utils
  skip_before_action :verify_authenticity_token

  def register
    user = User.new(
      name: user_params[:name],
      email: user_params[:email],
      password: user_params[:password],
      password_confirmation: user_params[:password_confirmation],
      role: user_params[:role],
      city: user_params[:city],
      country: user_params[:country]
    )
    
    if user.save
      Rails.logger.info "User created: #{user.inspect}"
      Rails.logger.info "Password digest: #{user.password_digest}"
      token = generate_token(user.id)
      render json: { 
        status: 200, 
        message: "User registered successfully",
        token: token
      }
    else
      Rails.logger.info "Registration errors: #{user.errors.full_messages.join(', ')}"
      render json: { 
        status: 400, 
        message: user.errors.full_messages.join(', ')
      }
    end
  end

  def login
    user = User.find_by(email: login_params[:email])
    Rails.logger.info "User: #{user.inspect}"
    Rails.logger.info "Login params: #{login_params.inspect}"
    Rails.logger.info "Password digest: #{user.password_digest}"
    if user && user.authenticate(login_params[:password])
      Rails.logger.info "Authentication successful"
      token = JwtAuthenticator.new.encode(user)
      Rails.logger.info "Generated token: #{token}"
      render json: { 
        status: 200, 
        message: "User logged in successfully",
        token: token
      }
    else
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
