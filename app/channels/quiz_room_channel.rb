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
  end

  def answer_question(data)
    room = GameRoom.find(@room_id)
    user = current_user

    room.with_lock do
      room.reload

      # Ako je user već odgovorio, izlazimo
      next if room.already_answered?(user.id)

      correct = (room.current_question.correct_option == data["answer"])
      room.mark_answered(user.id, correct)

      ActionCable.server.broadcast "quiz_room_#{@room_id}", {
        event: "answer_result",
        user_id: user.id,
        correct: correct,
        correct_option: room.current_question.correct_option
      }

      # Ako su obojica odgovorili, prelazi se dalje
      if room.both_answered?
        room.next_question!

        # Ponovo proveravamo game_over POSLE next_question
        if room.game_over?
          ActionCable.server.broadcast "quiz_room_#{@room_id}", {
            event: "game_over",
            p1_score: room.score_p1,
            p2_score: room.score_p2,
            winner: room.score_p1 > room.score_p2 ? room.player1_id : room.player2_id
          }
        else
          q = room.current_question

          # zaštita — nikad ne šaljemo serialize_question(nil)
          if q.present?
            ActionCable.server.broadcast "quiz_room_#{@room_id}", {
              event: "new_question",
              current_question: serialize_question(q),
              index: room.current_index
            }
          else
            # fallback — ako ikada dobijemo nil, šalji game_over
            ActionCable.server.broadcast "quiz_room_#{@room_id}", {
              event: "game_over",
              p1_score: room.score_p1,
              p2_score: room.score_p2,
              winner: room.score_p1 > room.score_p2 ? room.player1_id : room.player2_id
            }
          end
        end
      end
    end
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
