class QuizRoomChannel < ApplicationCable::Channel
  def subscribed
    @room_id = params["room_id"]
    stream_from "quiz_room_#{@room_id}"
  end

  def room_info
    room = GameRoom.find(@room_id)

    # po potrebi: proveri da li oba igrača prisutna
    question = room.pick_random_question

    ActionCable.server.broadcast("quiz_room_#{@room_id}", {
      event: "room_info",
      room_id: @room_id,
      players: [
        { id: room.player1.id, name: room.player1.name },
        (room.player2 ? { id: room.player2.id, name: room.player2.name } : nil)
    ].compact,
      current_question: {
        text: question.question,
        a: question.option_a,
        b: question.option_b,
        c: question.option_c,
        d: question.option_d,
        id: question.id
      }
    })
  end

  def answer_question(data)
    room = GameRoom.find(@room_id)
    question = QuizQuestion.find(data["question_id"])

    correct = (data["answer"] == question.correct_option)

    ActionCable.server.broadcast("quiz_room_#{@room_id}", {
      event: "answer_result",
      correct: correct,
      user_id: current_user.id,
      correct_option: question.correct_option
    })

    # može odmah sledeće pitanje:
    next_q = room.pick_random_question

    ActionCable.server.broadcast("quiz_room_#{@room_id}", {
      event: "new_question",
      current_question: {
        text: next_q.question,
        a: next_q.option_a,
        b: next_q.option_b,
        c: next_q.option_c,
        d: next_q.option_d,
        id: next_q.id
      }
    })
  end
end
