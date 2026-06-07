require "test_helper"

class HikeRouteTest < ActiveSupport::TestCase
  test "brisanje rute briše sve njene tačke" do
    route = hike_routes(:test_route)

    # Potvrdi da ruta ima tačke pre brisanja
    assert_equal 3, route.points.count, "Ruta treba da ima 3 tačke pre brisanja"

    point_ids = route.points.pluck(:id)

    # Obriši rutu
    route.destroy

    # Potvrdi da ni jedna tačka više ne postoji
    remaining = Point.where(id: point_ids).count
    assert_equal 0, remaining, "Sve tačke rute treba da budu obrisane"
  end

  test "brisanje rute ne briše tačke druge rute" do
    user = users(:test_user)

    other_route = HikeRoute.create!(
      title: "Druga ruta",
      description: "Opis",
      difficulty: "srednja",
      distance: 3.0,
      duration: 60,
      status: "finalized",
      location_latitude: 44.0,
      location_longitude: 20.0,
      user: user
    )
    other_point = Point.create!(lat: 44.0, lng: 20.0, hike_route: other_route)

    route_to_delete = hike_routes(:test_route)
    route_to_delete.destroy

    assert Point.exists?(other_point.id), "Tačke druge rute ne smeju biti obrisane"

    other_route.destroy
  end

  test "brisanje rute ažurira statistiku korisnika" do
    user = users(:test_user)
    route = hike_routes(:test_route)

    route.destroy

    user.reload
    assert_equal 0.0, user.total_distance
    assert_equal 0, user.total_duration
  end
end
