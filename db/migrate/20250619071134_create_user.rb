class CreateUser < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :password
      t.string :password_confirmation
      t.string :role
      t.string :city
      t.string :country     
      t.timestamps
    end
  end
end
