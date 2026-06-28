require "rexml/document"

# Parses a GPX track and creates a finalized HikeRoute (points + distance +
# duration computed). Elevation is backfilled separately (ElevationJob /
# ElevationService) since it requires a slow external DEM lookup.
class GpxImporter
  # Returns [track_name, [{lat:, lng:, timestamp:}, ...]].
  def self.parse(gpx_string)
    doc = REXML::Document.new(gpx_string)
    name = REXML::XPath.first(doc, "//*[local-name()='trk']/*[local-name()='name']")&.text&.strip
    name = REXML::XPath.first(doc, "//*[local-name()='name']")&.text&.strip if name.blank?
    name = name&.sub(/\s*[-–]\s*Wikiloc\s*\z/i, "")&.sub(/\A\s*Wikiloc\s*[-–]\s*/i, "")&.strip

    points = REXML::XPath.match(doc, "//*[local-name()='trkpt']").map do |pt|
      time = REXML::XPath.first(pt, "*[local-name()='time']")&.text
      {
        lat: pt.attribute("lat")&.value.to_f,
        lng: pt.attribute("lon")&.value.to_f,
        timestamp: (Time.parse(time) rescue nil),
      }
    end
    [name, points]
  end

  # Creates a finalized route from a GPX string for `user`.
  def self.create_route(user:, gpx:, title: nil, difficulty: nil, tags: nil, description: nil)
    name, trkpts = parse(gpx)
    raise "GPX fajl ne sadrži track tačke (<trkpt>)." if trkpts.blank?

    # Stable, increasing timestamps so distance/duration compute correctly.
    base = trkpts.first[:timestamp] || Time.current
    trkpts.each_with_index { |p, i| p[:timestamp] ||= base + (i * 30) }

    attrs = {
      title: title.presence || name.presence || "Uvezena ruta",
      description: description.to_s,
      difficulty: difficulty.presence || "Srednja",
      status: "tracking",
      location_latitude: trkpts.first[:lat],
      location_longitude: trkpts.first[:lng],
      duration: 0, distance: 0,
    }
    # Only set tags when the column exists (prod may not be migrated yet).
    if HikeRoute.column_names.include?("tags") && Array(tags).reject(&:blank?).any?
      attrs[:tags] = Array(tags)
    end

    route = nil
    ActiveRecord::Base.transaction do
      route = user.hike_routes.create!(attrs)
      now = Time.current
      Point.insert_all!(trkpts.map { |p|
        p.merge(hike_route_id: route.id, user_id: user.id, created_at: now, updated_at: now)
      })
      route.finalize_route!   # computes distance + duration from points
    end
    route
  end
end
