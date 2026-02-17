class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:google_auth]

  # POST /auth/google
  def google_auth
    request_body = request.body.read
    
    id_token = params[:id_token]
    
    begin
      # Initialize the validator
      validator = Google::Auth::IDTokens::Verifier.new
      
      # Get the certificates
      certs_uri = 'https://www.googleapis.com/oauth2/v3/certs'
      certificates = Net::HTTP.get(URI(certs_uri))
      
      # Verify the token
      payload = Google::Auth::IDTokens.verify_oidc(
        id_token,
        aud: ENV['GOOGLE_CLIENT_ID']
      )
      
      # Find or create the user
      user = User.find_or_initialize_by(email: payload['email'])
      
      if user.new_record?
        # Generate a random password
        password = SecureRandom.hex(16)
        
        # Set user attributes with default values
        user.assign_attributes(
          name: payload['name'],
          password: password,
          password_confirmation: password,  # Match the password
          role: 'user',                    # Default role
          city: 'Unknown',                 # Default city
          country: 'Unknown',              # Default country
          email_confirmed_at: Time.current # Auto-confirm email since Google already verified it
        )
        
        unless user.save
          Rails.logger.error "Failed to create user: #{user.errors.full_messages.join(', ')}"
          render json: { 
            error: 'Failed to create user',
            details: user.errors.full_messages
          }, status: :unprocessable_entity
          return
        end
        Rails.logger.info "Successfully created user: #{user.id}"
      end
      
      # Generate a JWT token for the user
      token = JwtAuthenticator.new.encode(user)
      @current_user = user
      
      # Set the JWT token in an HTTP-only cookie
      cookies.signed[:jwt] = {
        value: token,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :strict,
        expires: 1.week.from_now
      }
      
      render json: { 
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          token: token
        },
        message: 'Successfully authenticated with Google',
        user_id: user.id,
        token: token
      }, status: :ok
      
    rescue Google::Auth::IDTokens::SignatureError, Google::Auth::IDTokens::AudienceMismatchError => e
      Rails.logger.error "Google token validation error: #{e.message}"
      render json: { error: 'Invalid Google token' }, status: :unauthorized
    rescue => e
      Rails.logger.error "Google auth error: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: 'Authentication failed' }, status: :internal_server_error
    end
  end
end
