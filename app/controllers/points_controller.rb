class PointsController < ApiController
  def create
    route = HikeRoute.find(params[:route_id])
    point = route.points.create!(
      lat: params[:lat],
      lng: params[:lng],
      timestamp: params[:timestamp]
    )
    render json: point
  end
end