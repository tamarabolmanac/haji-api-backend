class ApplicationController < ActionController::Base
  include Utils

  allow_browser versions: :modern

  private

  def authenticate_user
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    token = request.headers['Authorization']&.split(' ')&.last
    @current_user = JwtAuthenticator.new.decode(token) if token
  end

  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end
