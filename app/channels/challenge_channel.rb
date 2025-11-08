class ChallengeChannel < ApplicationCable::Channel
  def subscribed
    stream_from "challenge_#{current_user.id}"
  end

  # client sends: {action: "send_challenge", opponent_id: X}
  def send_challenge(data)
    opponent_id = data["opponent_id"]

    ActionCable.server.broadcast(
      "challenge_#{opponent_id}",
      {
        event: "challenge_received",
        from_id: current_user.id,
        from_name: current_user.name
      }
    )
  end

  def accept_challenge(data)
    Rails.logger.info("Accepting challenge from #{current_user.id} to #{data["opponent_id"]}")
    opponent_id = data["opponent_id"]

    room = GameRoom.create!(
      player1_id: current_user.id,
      player2_id: opponent_id
    )

    room.assign_questions!

    ActionCable.server.broadcast("challenge_#{opponent_id}", {
      event: "challenge_accepted",
      room_id: room.id,
      opponent_name: current_user.name
    })

    ActionCable.server.broadcast("challenge_#{current_user.id}", {
      event: "challenge_accepted",
      room_id: room.id,
      opponent_name: User.find(opponent_id).name
    })
  end
end
