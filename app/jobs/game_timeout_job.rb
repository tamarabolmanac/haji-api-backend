class GameTimeoutJob < ApplicationJob
  queue_as :default

  def perform(room_id, expected_index)
    Rails.logger.info "!!!!!!! Performing timeout for room #{room_id}"
    room = GameRoom.find_by(id: room_id)
    return unless room
    return if room.game_over?

    # Ako je neko odgovorio ili je već proslijeđeno na novo pitanje:
    return if room.current_index != expected_index

    room.next_question!

    if room.game_over?
      ActionCable.server.broadcast "quiz_room_#{room_id}", {
        event: "game_over",
        p1_score: room.score_p1,
        p2_score: room.score_p2,
        winner: room.score_p1 > room.score_p2 ? room.player1_id : room.player2_id
      }
      return
    end

    q = room.current_question
    ActionCable.server.broadcast "quiz_room_#{room_id}", {
      event: "new_question",
      current_question: serialize_question(q),
      index: room.current_index
    }

    # zakaži timeout za sledeće pitanje
    GameTimeoutJob.set(wait: 10.seconds).perform_later(room.id, room.current_index)
  end

  private

  def serialize_question(q)
    {
      id: q.id,
      text: q.question,
      a: q.option_a,
      b: q.option_b,
      c: q.option_c,
      d: q.option_d
    }
  end
end
