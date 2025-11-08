class QuizRoomChannel < ApplicationCable::Channel
  def subscribed
    @room_id = params["room_id"]
    stream_from "quiz_room_#{@room_id}"
  end

  def room_info
    room = GameRoom.find(@room_id)

    question = room.current_question

    ActionCable.server.broadcast "quiz_room_#{@room_id}", {
      event: "room_info",
      room_id: @room_id,
      players: [
        { id: room.player1.id, name: room.player1.name },
        (room.player2 ? { id: room.player2.id, name: room.player2.name } : nil)
      ].compact,
      current_question: serialize_question(question),
      index: room.current_index,
      p1_score: room.score_p1,
      p2_score: room.score_p2
    }

    #schedule_timeout(room)
  end


  def answer_question(data)
    room = GameRoom.find(@room_id)
    user = current_user
    question = room.current_question

    unless room.already_answered?(user.id)
      correct = (question.correct_option == data["answer"])
      room.mark_answered(user.id, correct)

      Rails.logger.info "!!!!!!! Answered #{room.already_answered?(user.id)}"

      ActionCable.server.broadcast "quiz_room_#{@room_id}", {
          event: "answer_result",
          user_id: user.id,
          correct: correct,
          correct_option: question.correct_option
      }

      # If both players have answered, advance immediately
      if room.both_answered?
        room.with_lock do
          room.reload
          if room.both_answered? && !room.game_over?
            room.next_question!

            if room.game_over?
              ActionCable.server.broadcast "quiz_room_#{@room_id}", {
                event: "game_over",
                p1_score: room.score_p1,
                p2_score: room.score_p2,
                winner: room.score_p1 > room.score_p2 ? room.player1_id : room.player2_id
              }
            else
              q = room.current_question
              ActionCable.server.broadcast "quiz_room_#{@room_id}", {
                event: "new_question",
                current_question: serialize_question(q),
                index: room.current_index
              }
              # schedule timeout for the new question index
              #schedule_timeout(room)
            end
          end
        end
      end
    end
  end

  private

  def schedule_timeout(room)
    Rails.logger.info "!!!!!!! Scheduling timeout for room #{room.id}"
    GameTimeoutJob.set(wait: 10.seconds).perform_later(room.id, room.current_index)
  end

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
