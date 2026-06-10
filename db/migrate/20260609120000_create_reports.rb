class CreateReports < ActiveRecord::Migration[8.0]
  def change
    create_table :reports do |t|
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      t.references :hike_route, null: true, foreign_key: true
      t.references :reported_user, null: true, foreign_key: { to_table: :users }
      t.string :reason, null: false
      t.text :details
      t.string :status, null: false, default: "pending"
      t.timestamps
    end

    add_index :reports, :status
  end
end
