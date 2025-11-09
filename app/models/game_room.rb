class GameRoom < ApplicationRecord
  belongs_to :player1, class_name: "User"
  belongs_to :player2, class_name: "User", optional: true

  # npr. kada se kreira soba ili kada oba igrača uđu
  def pick_random_question
    QuizQuestion.order("RANDOM()").first
  end

  def answered_hash
    answered || {}
  end

  def assign_questions!
    self.questions = QuizQuestion.order("RANDOM()").limit(10).pluck(:id)
    self.current_index = 0
    self.answered = {}
    save!
  end

  def current_question
    return nil if current_index >= questions.length
    QuizQuestion.find(questions[current_index])
  end

  def mark_answered(user_id, correct)
    self.answered = answered_hash.merge(user_id.to_s => correct)

    if user_id == player1_id && correct
      self.score_p1 += 1
    elsif user_id == player2_id && correct
      self.score_p2 += 1
    end

    save
  end

  def both_answered?
    player_ids = [player1_id, player2_id].compact
    player_ids.all? { |id| answered_hash.key?(id.to_s) }
  end

  def already_answered?(user_id)
    Rails.logger.info "ALREADY ANSWERED: #{answered_hash}"
    answered_hash.key?(user_id.to_s)
  end

  def next_question!
    self.current_index += 1
    self.answered = {}
    save!
  end

  def game_over?
    current_index >= questions.length
  end
end
