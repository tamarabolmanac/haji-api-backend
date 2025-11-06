module ApplicationCable
  class Connection < ActionCable::Connection::Base
    include Utils
    identified_by :current_user

    def connect
      self.current_user = authenticate_user
      OnlineTracker.add(current_user.id)
      Rails.logger.info "✅ WS connected: #{current_user.email}"
    end

    def disconnect
      return unless current_user
      OnlineTracker.remove(current_user.id)
      Rails.logger.info "❌ WS disconnected: #{current_user.email}"
    end

    private

    def authenticate_user
      token = request.params[:token]

      reject_unauthorized_connection unless token.present?

      # skini Bearer prefix ako postoji
      jwt = token.split(" ").last rescue nil

      payload = JwtAuthenticator.new.decode(jwt)
      Rails.logger.info "✅ DESODED: #{payload}"
      reject_unauthorized_connection unless payload.present?

      user = User.find_by(id: payload[0]["user_id"])
      reject_unauthorized_connection unless user.present?

      user
    end
  end
end
 