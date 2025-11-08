class AddQuizFieldsToGameRooms < ActiveRecord::Migration[8.0]
  def change
    add_column :game_rooms, :questions, :jsonb, default: []
    add_column :game_rooms, :current_index, :integer, default: 0
    add_column :game_rooms, :answered, :jsonb, default: {}
    add_column :game_rooms, :score_p1, :integer, default: 0
    add_column :game_rooms, :score_p2, :integer, default: 0
  end
end
