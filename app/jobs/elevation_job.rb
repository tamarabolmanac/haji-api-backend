# Backfills elevation for a route's GPS points (via OpenTopoData) in the
# background, so the elevation profile is ready before anyone opens the route.
# Enqueued when a route is finalized. Safe to re-run — ElevationService only
# queries points whose elevation is still missing.
class ElevationJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError
  # Partial/failed DEM fetches (bad network, API down) raise FetchError after
  # persisting what succeeded — retry with backoff finishes the missing points.
  # Waits roughly: 3s, 18s, 1.5min, 4.5min.
  retry_on ElevationService::FetchError, wait: :polynomially_longer, attempts: 5

  def perform(hike_route_id)
    route = HikeRoute.find_by(id: hike_route_id)
    return unless route

    ElevationService.new(route).profile
    # Warm/refresh the endpoint cache so the first view is instant.
    Rails.cache.delete("hike:#{route.id}:elevation")
  end
end
