class CreateGameRooms < ActiveRecord::Migration[8.0]
  def change
    create_table :game_rooms do |t|
      t.integer :player1_id
      t.integer :player2_id
      t.string :status

      t.timestamps
    end
  end
end
