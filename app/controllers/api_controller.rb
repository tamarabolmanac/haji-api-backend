class ApiController < ActionController::API
  include Utils
  
  private
  
  def authenticate_user
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    token = request.headers['Authorization']&.split(' ')&.last
    Rails.logger.info "Auth token: #{token}"
    if token
      begin
        decoded_token = Utils::JwtAuthenticator.new.decode(token)
        Rails.logger.info "Decoded token: #{decoded_token}"
        @current_user = User.find(decoded_token[0]['user_id'])
        Rails.logger.info "Found user: #{@current_user.inspect}"
      rescue JWT::DecodeError, JWT::ExpiredSignature => e
        # Token is invalid or expired, log out the user
        Rails.logger.error "Token decode error: #{e.message}"
        @current_user = nil
      end
    else
      Rails.logger.info "No token provided"
    end
  end

  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end