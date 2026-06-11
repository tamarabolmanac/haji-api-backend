class CreateProtectedAreas < ActiveRecord::Migration[8.0]
  def change
    create_table :protected_areas do |t|
      t.string  :name,        null: false
      t.string  :area_type,   null: false  # 'national_park' | 'nature_park' | 'mountain'
      t.decimal :lat,         precision: 10, scale: 6
      t.decimal :lon,         precision: 10, scale: 6
      t.text    :description
      t.string  :legacy_image_path  # za stare /img/ putanje dok se ne uploaduju na R2

      t.timestamps
    end

    add_index :protected_areas, :area_type
    add_index :protected_areas, :name, unique: true
  end
end
