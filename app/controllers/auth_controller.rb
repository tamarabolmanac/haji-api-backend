class AuthController < ActionController::API
  include Utils

  def register
    # Explicit check for duplicate email to return a clear, specific message
    if User.exists?(email: user_params[:email])
      return render json: {
        status: 409,
        message: "Korisnik sa ovom email adresom već postoji",
        errors: ["Email je već zauzet"]
      }, status: :conflict
    end

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
      user.send_confirmation_email!

      token = generate_token(user)
      render json: { 
        status: 200, 
        message: "User registered successfully",
        token: token
      }, status: :ok
    else
      # Validation failed - return detailed errors
      render json: {
        status: 422,
        message: "Registracija neuspešna",
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    # Handle any accidental bang-method calls inside model callbacks
    Rails.logger.error "Registration failed (RecordInvalid): #{e.record.errors.full_messages.join(', ')}"
    render json: {
      status: 422,
      message: "Registracija neuspešna",
      errors: e.record.errors.full_messages.presence || [e.message]
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Registration failed (Exception): #{e.class} - #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    render json: {
      status: 500,
      message: "Greška servera",
      error: e.message
    }, status: :internal_server_error
  end

  def login
    user = User.find_by(email: login_params[:email])

    if user && user.authenticate(login_params[:password])
      if !user.confirmed?
        return render json: { 
          status: 401, 
          message: "User not confirmed"
        }
      else
        token = JwtAuthenticator.new.encode(user)
        render json: { 
          status: 200, 
          message: "User logged in successfully",
          token: token,
          user_id: user.id
        }
      end
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
