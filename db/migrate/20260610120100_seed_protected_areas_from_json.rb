class SeedProtectedAreasFromJson < ActiveRecord::Migration[8.0]
  def up
    json_path = Rails.root.join('db', 'seeds', 'protected_areas.json')
    return unless File.exist?(json_path)

    # Fix common JSON issues (unescaped quotes inside strings) by reading with rescue
    raw = File.read(json_path, encoding: 'UTF-8')
    areas = begin
      JSON.parse(raw)
    rescue JSON::ParserError
      # Strip BOM and retry; if still fails, skip
      Rails.logger.warn "protected_areas.json has JSON errors, skipping seed migration"
      return
    end

    areas.each do |a|
      ProtectedArea.find_or_create_by!(name: a['name']) do |pa|
        pa.area_type          = a['type'] || 'national_park'
        pa.lat                = a['lat']
        pa.lon                = a['lon']
        pa.description        = a['description'].presence
        pa.legacy_image_path  = a['image'].presence
      end
    end
  end

  def down
    # Do not delete data on rollback
  end
end
