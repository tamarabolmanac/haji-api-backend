class ApiController < ActionController::API
  include Utils
  
  private
  
  def authenticate_user
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    auth_header = request.headers['Authorization']
    
    token = auth_header&.split(' ')&.last
    
    if token
      begin
        decoded_token = Utils::JwtAuthenticator.new.decode(token)
        user_id = decoded_token[0]['user_id']
        @current_user = User.find(user_id)
      rescue JWT::DecodeError, JWT::ExpiredSignature => e
        # Token is invalid or expired, log out the user
        Rails.logger.error "Token decode error: #{e.message}"
        Rails.logger.error "Token that failed: #{token}"
        @current_user = nil
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "User not found: #{e.message}"
        @current_user = nil
      end
    end
  end

  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end