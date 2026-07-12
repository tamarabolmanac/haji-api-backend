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
  # Raised when one or more DEM batches couldn't be fetched (network/API down).
  # Whatever was fetched is already persisted, so a retry only re-queries the
  # points that are still missing — ElevationJob retries on this.
  class FetchError < StandardError; end

  BASE_URL = ENV.fetch("OPENTOPODATA_URL", "http://opentopodata:5000")
  DATASET  = ENV.fetch("OPENTOPODATA_DATASET", "srtm30m")
  BATCH    = 100 # OpenTopoData default max_locations_per_request
  # Public api.opentopodata.org allows 1 req/s — set OPENTOPODATA_THROTTLE_S=1
  # there. Self-hosted needs no throttle (0).
  THROTTLE_S = ENV.fetch("OPENTOPODATA_THROTTLE_S", "0").to_f
  EARTH_R  = 6_371_000.0 # meters

  def initialize(hike_route)
    @hike_route = hike_route
  end

  # backfill: true performs the slow external DEM lookup (only safe in a
  # background job — never in a web request). backfill: false returns whatever
  # elevations are already persisted, so the endpoint can respond instantly.
  def profile(backfill: true)
    points = @hike_route.points.order(:timestamp).to_a
    return [] if points.empty?

    backfill_missing!(points) if backfill

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
  # batches, and persist the result. Successful batches are persisted even when
  # others fail; a FetchError at the end makes the enclosing job retry, and the
  # retry only re-queries the points still missing.
  def backfill_missing!(points)
    missing = points.select { |p| p.elevation.nil? }
    return if missing.empty?

    failed_batches = 0
    total_batches = 0
    updates = {} # point_id => elevation
    missing.each_slice(BATCH) do |batch|
      total_batches += 1
      locations = batch.map { |p| "#{p.lat},#{p.lng}" }.join("|")
      results = fetch(locations)
      if results.nil?
        failed_batches += 1
        next
      end

      batch.each_with_index do |p, i|
        ele = results.dig(i, "elevation")
        next if ele.nil?
        p.elevation = ele # keep in-memory so the returned profile is complete
        updates[p.id] = ele
      end

      sleep(THROTTLE_S) if THROTTLE_S.positive?
    end

    persist_elevations!(updates)

    if failed_batches.positive?
      raise FetchError,
            "route #{@hike_route.id}: #{failed_batches}/#{total_batches} elevation batches failed"
    end
  end

  # Persist all fetched elevations in a few bulk UPDATEs (one per chunk) instead
  # of one round-trip per point. Critical when the DB is remote (Supabase): a
  # dense route with 10k points would otherwise mean 10k UPDATE round-trips.
  # ids/elevations are coerced to Integer/Float, so the inlined VALUES are safe.
  def persist_elevations!(updates)
    return if updates.empty?

    updates.each_slice(500) do |chunk|
      values = chunk.map { |id, ele| "(#{id.to_i}, #{ele.to_f})" }.join(",")
      sql = <<~SQL.squish
        UPDATE points AS p SET elevation = v.ele
        FROM (VALUES #{values}) AS v(id, ele)
        WHERE p.id = v.id
      SQL
      Point.connection.execute(sql)
    end
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
