class CreatePoints < ActiveRecord::Migration[8.0]
  def change
    create_table :points do |t|
      t.float :lat
      t.float :lng
      t.bigint :timestamp
      t.references :hike_route, null: false, foreign_key: true

      t.timestamps
    end
  end
end
