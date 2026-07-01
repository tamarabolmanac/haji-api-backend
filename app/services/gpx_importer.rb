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

  # Minimum spacing between kept points. A dense GPX (e.g. 10k points over 6 km)
  # bloats the DB and the map without adding real detail; ~10 m spacing keeps the
  # track shape while cutting point counts by 10-20x.
  MIN_GAP_M = 10.0
  EARTH_R_M = 6_371_000.0

  # Drops points closer than MIN_GAP_M to the previously kept point. First and
  # last points are always kept, so endpoints (and total length) are preserved.
  def self.downsample(points)
    return points if points.size <= 2

    kept = [points.first]
    points[1..-2].each do |p|
      kept << p if haversine_m(kept.last, p) >= MIN_GAP_M
    end
    kept << points.last
    kept
  end

  def self.haversine_m(a, b)
    rad = Math::PI / 180.0
    dlat = (b[:lat] - a[:lat]) * rad
    dlng = (b[:lng] - a[:lng]) * rad
    h = Math.sin(dlat / 2)**2 +
        Math.cos(a[:lat] * rad) * Math.cos(b[:lat] * rad) * Math.sin(dlng / 2)**2
    2 * EARTH_R_M * Math.asin(Math.sqrt(h))
  end

  # Creates a finalized route from a GPX string for `user`.
  def self.create_route(user:, gpx:, title: nil, difficulty: nil, tags: nil, description: nil)
    name, trkpts = parse(gpx)
    raise "GPX fajl ne sadrži track tačke (<trkpt>)." if trkpts.blank?

    raw_count = trkpts.size
    trkpts = downsample(trkpts)
    Rails.logger.info("[GpxImporter] downsampled #{raw_count} -> #{trkpts.size} points (min #{MIN_GAP_M}m)")

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
