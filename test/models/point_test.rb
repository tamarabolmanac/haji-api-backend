require "test_helper"

class PointTest < ActiveSupport::TestCase
  setup do
    @route = hike_routes(:test_route)
  end

  test "snimanje tačke sa lat/lng" do
    point = @route.points.create!(lat: 44.9, lng: 20.5)
    assert point.persisted?
    assert_in_delta 44.9, point.lat, 0.0001
    assert_in_delta 20.5, point.lng, 0.0001
  end

  test "snimanje tačke sa Unix timestamp-om" do
    ts = 1_700_000_000
    point = @route.points.create!(lat: 44.9, lng: 20.5, timestamp: Time.zone.at(ts))
    assert_equal Time.zone.at(ts).to_i, point.timestamp.to_i
  end

  test "tačka bez lat/lng nije validna" do
    point = @route.points.build(lat: nil, lng: nil)
    assert_not point.save
  end

  test "client_uuid deduplikacija — ista tačka se ne snimi dva puta" do
    uuid = SecureRandom.uuid
    @route.points.create!(lat: 44.9, lng: 20.5, client_uuid: uuid)

    # Isti client_uuid — find_or_initialize_by treba da pronađe postojeću
    existing = @route.points.find_or_initialize_by(client_uuid: uuid)
    assert existing.persisted?, "Tačka sa istim client_uuid treba već da postoji"
  end
end
