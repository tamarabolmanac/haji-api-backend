class CreateQuizQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :quiz_questions do |t|
      t.string :question
      t.string :option_a
      t.string :option_b
      t.string :option_c
      t.string :option_d
      t.string :correct_option

      t.timestamps
    end
  end
end
