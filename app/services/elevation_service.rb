require "net/http"
require "json"

# Fills in and returns the elevation profile for a hike route's GPS points by
# querying a self-hosted OpenTopoData instance (see docker-compose-dev.yml).
#
# Elevations are persisted on each Point (the `elevation` column) so we only
# hit OpenTopoData once per point. Returns an array of profile samples ordered
# by timestamp:
#   [{ lat:, lng:, elevation:, distance_m: }, ...]
# where `distance_m` is cumulative distance along the track.
class ElevationService
  BASE_URL = ENV.fetch("OPENTOPODATA_URL", "http://opentopodata:5000")
  DATASET  = ENV.fetch("OPENTOPODATA_DATASET", "srtm30m")
  BATCH    = 100 # OpenTopoData default max_locations_per_request
  EARTH_R  = 6_371_000.0 # meters

  def initialize(hike_route)
    @hike_route = hike_route
  end

  def profile
    points = @hike_route.points.order(:timestamp).to_a
    return [] if points.empty?

    backfill_missing!(points)

    cumulative = 0.0
    prev = nil
    points.map do |p|
      cumulative += haversine(prev, p) if prev
      prev = p
      { lat: p.lat, lng: p.lng, elevation: p.elevation, distance_m: cumulative.round }
    end
  end

  private

  # Query OpenTopoData for any point that doesn't yet have an elevation, in
  # batches, and persist the result. Failures are logged and left as nil so the
  # map still renders.
  def backfill_missing!(points)
    missing = points.select { |p| p.elevation.nil? }
    return if missing.empty?

    missing.each_slice(BATCH) do |batch|
      locations = batch.map { |p| "#{p.lat},#{p.lng}" }.join("|")
      results = fetch(locations)
      next unless results

      batch.each_with_index do |p, i|
        ele = results.dig(i, "elevation")
        p.update_column(:elevation, ele) unless ele.nil?
      end
    end
  rescue => e
    Rails.logger.warn("[ElevationService] backfill failed: #{e.class}: #{e.message}")
  end

  def fetch(locations)
    uri = URI("#{BASE_URL}/v1/#{DATASET}")
    uri.query = URI.encode_www_form(locations: locations)
    # use_ssl must be on for https (e.g. the public api.opentopodata.org);
    # self-hosted runs over plain http on :5000.
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                          open_timeout: 5, read_timeout: 15) do |http|
      http.get(uri.request_uri)
    end
    return nil unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)["results"]
  rescue => e
    Rails.logger.warn("[ElevationService] fetch failed: #{e.class}: #{e.message}")
    nil
  end

  def haversine(a, b)
    return 0.0 unless a && b

    dlat = deg(b.lat - a.lat)
    dlng = deg(b.lng - a.lng)
    h = Math.sin(dlat / 2)**2 +
        Math.cos(deg(a.lat)) * Math.cos(deg(b.lat)) * Math.sin(dlng / 2)**2
    2 * EARTH_R * Math.asin(Math.sqrt(h))
  end

  def deg(d) = d * Math::PI / 180.0
end
