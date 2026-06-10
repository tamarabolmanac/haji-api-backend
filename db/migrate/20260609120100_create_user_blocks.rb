class CreateUserBlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :user_blocks do |t|
      t.references :blocker, null: false, foreign_key: { to_table: :users }
      t.references :blocked, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :user_blocks, [:blocker_id, :blocked_id], unique: true
  end
end
