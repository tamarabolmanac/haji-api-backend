require 'csv'

class OsmRoutesController < ActionController::API

  def index
    csv_path = Rails.root.join("db", "seeds", "serbia_routes.csv")

    unless File.exist?(csv_path)
      render json: { error: "CSV nije pronađen. Pokreni: rails routes:fetch_serbia" }, status: :not_found
      return
    end

    routes = []
    CSV.foreach(csv_path, headers: true, encoding: "UTF-8") do |row|
      lat = row["lat"].to_f
      lon = row["lon"].to_f
      next if lat.zero? || lon.zero?

      routes << {
        name:        row["name"],
        distance_km: row["distance_km"].presence&.to_f,
        terrain:     row["terrain_tags"].to_s.split("|").reject(&:empty?),
        lat:         lat,
        lon:         lon,
        description: row["description"],
        network:     row["network"],
        difficulty:  row["difficulty"]
      }
    end

    render json: routes, status: :ok
  end
end
