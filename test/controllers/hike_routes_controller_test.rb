require "test_helper"

class HikeRoutesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:test_user)
    @token = Utils::JwtAuthenticator.new.encode(@user)
    @auth_headers = { "Authorization" => "Bearer #{@token}" }
  end

  # --- track_point ---

  test "track_point kreira novu rutu i snima prvu tačku" do
    assert_difference("HikeRoute.count", 1) do
      assert_difference("Point.count", 1) do
        post "/routes/track_point",
          params: { latitude: "44.8125", longitude: "20.4612", timestamp: "2026-06-18T10:00:00Z" },
          headers: @auth_headers
      end
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 200, json["status"]
    assert json["route_id"].present?
    assert json["point"]["id"].present?

    HikeRoute.find(json["route_id"]).destroy
  end

  test "track_point dodaje tačku na postojeću rutu" do
    route = hike_routes(:test_route)
    route.update_column(:user_id, @user.id)
    before_count = route.points.count

    post "/routes/track_point",
      params: { route_id: route.id, latitude: "44.8200", longitude: "20.4700" },
      headers: @auth_headers

    assert_response :success
    assert_equal before_count + 1, route.points.reload.count
  end

  test "track_point odbija bez tokena" do
    post "/routes/track_point",
      params: { latitude: "44.8", longitude: "20.4" }
    assert_response :unauthorized
  end

  test "track_point vraća 403 ako ruta pripada drugom korisniku" do
    other_user = User.create!(
      name: "Drugi", email: "drugi@hajki.com",
      password: "pass1234", password_confirmation: "pass1234",
      role: "user", city: "Niš", country: "Srbija",
      email_confirmed_at: Time.current
    )
    other_route = other_user.hike_routes.create!(
      title: "Tuđa ruta", description: "", difficulty: "medium",
      distance: 0, duration: 0, status: "tracking"
    )

    post "/routes/track_point",
      params: { route_id: other_route.id, latitude: "44.8", longitude: "20.4" },
      headers: @auth_headers

    assert_response :success  # controller uvek vraca 200 envelope
    json = JSON.parse(response.body)
    assert_equal 403, json["status"]
  ensure
    other_route&.destroy
    other_user&.destroy
  end

  # --- track_points_bulk ---

  test "track_points_bulk kreira rutu i snima više tačaka" do
    points = [
      { lat: 44.81, lng: 20.46, timestamp: "2026-06-18T10:00:00Z", client_uuid: SecureRandom.uuid },
      { lat: 44.82, lng: 20.47, timestamp: "2026-06-18T10:01:00Z", client_uuid: SecureRandom.uuid },
      { lat: 44.83, lng: 20.48, timestamp: "2026-06-18T10:02:00Z", client_uuid: SecureRandom.uuid }
    ]

    assert_difference("HikeRoute.count", 1) do
      assert_difference("Point.count", 3) do
        post "/routes/track_points_bulk",
          params: { points: points },
          headers: @auth_headers
      end
    end

    json = JSON.parse(response.body)
    assert_equal 200, json["status"]
    assert_equal 3, json["created"]
    assert_equal 0, json["skipped_duplicate"]

    HikeRoute.find(json["route_id"]).destroy
  end

  test "track_points_bulk preskaše duplikat client_uuid unutar istog zahteva" do
    uuid = SecureRandom.uuid
    points = [
      { lat: 44.81, lng: 20.46, client_uuid: uuid },
      { lat: 44.82, lng: 20.47, client_uuid: uuid }  # duplikat u istom zahtevu
    ]

    post "/routes/track_points_bulk",
      params: { points: points },
      headers: @auth_headers

    json = JSON.parse(response.body)
    # Duplikat u istom zahtevu se tiho preskoči (seen_uuids), pa je created = 1
    assert_equal 1, json["created"]
    assert_equal 1, json["points_count"]

    HikeRoute.find(json["route_id"]).destroy
  end

  test "track_points_bulk je idempotentan — ponovljen client_uuid iz ranijeg zahteva se broji kao skipped" do
    uuid = SecureRandom.uuid

    post "/routes/track_points_bulk",
      params: { points: [{ lat: 44.81, lng: 20.46, client_uuid: uuid }] },
      headers: @auth_headers
    route_id = JSON.parse(response.body)["route_id"]

    # Isti uuid u drugom zahtevu na istu rutu → već postoji u bazi
    post "/routes/track_points_bulk",
      params: { route_id: route_id, points: [{ lat: 44.81, lng: 20.46, client_uuid: uuid }] },
      headers: @auth_headers

    json = JSON.parse(response.body)
    assert_equal 0, json["created"]
    assert_equal 1, json["skipped_duplicate"]
    assert_equal 1, json["points_count"]

    HikeRoute.find(route_id).destroy
  end

  test "track_points_bulk dodaje tačke na postojeću rutu" do
    route = hike_routes(:test_route)
    route.update_column(:user_id, @user.id)
    before_count = route.points.count

    points = [
      { lat: 44.90, lng: 20.50 },
      { lat: 44.91, lng: 20.51 }
    ]

    post "/routes/track_points_bulk",
      params: { route_id: route.id, points: points },
      headers: @auth_headers

    json = JSON.parse(response.body)
    assert_equal 200, json["status"]
    assert_equal before_count + 2, route.points.reload.count
  end

  test "track_points_bulk vraća 400 za prazan niz tačaka" do
    post "/routes/track_points_bulk",
      params: { points: [] },
      headers: @auth_headers

    assert_response :bad_request
  end

  test "track_points_bulk vraća 400 za više od 200 tačaka" do
    points = 201.times.map { |i| { lat: 44.0 + i * 0.001, lng: 20.0 } }

    post "/routes/track_points_bulk",
      params: { points: points },
      headers: @auth_headers

    assert_response :bad_request
  end
end
