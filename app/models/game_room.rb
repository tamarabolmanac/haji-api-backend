class GameRoom < ApplicationRecord
  belongs_to :player1, class_name: "User"
  belongs_to :player2, class_name: "User", optional: true

  # npr. kada se kreira soba ili kada oba igrača uđu
  def pick_random_question
    QuizQuestion.order("RANDOM()").first
  end
end
