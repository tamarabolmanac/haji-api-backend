class ApplicationController < ActionController::Base
  include Utils

  allow_browser versions: :modern

  # Catch-all for unknown paths (e.g. bot probes: /xmlrpc.php, /wp-includes/..., /) — no RoutingError, clean 404
  def not_found
    head :not_found
  end

  private

  def authenticate_user
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    token = request.headers['Authorization']&.split(' ')&.last
    if token
      begin
        decoded_token = JwtAuthenticator.new.decode(token)
        @current_user = User.find(decoded_token[0]['user_id'])
      rescue JWT::DecodeError, JWT::ExpiredSignature
        # Token is invalid or expired, log out the user
        @current_user = nil
      end
    end
  end

  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end
