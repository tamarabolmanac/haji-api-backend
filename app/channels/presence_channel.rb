class PresenceChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "✅ SUBSCRIBED to PresenceChannel"
    stream_from "presence"

    ActionCable.server.broadcast(
      "presence",
      {
        event: "join",
        user: current_user.as_json(only: [:id, :name, :email])
      }
    )
  end

  def unsubscribed
    ActionCable.server.broadcast(
      "presence",
      {
        event: "leave",
        user: current_user.id
      }
    )
    Rails.logger.info "❌ UNSUBSCRIBED from PresenceChannel"
  end
end
