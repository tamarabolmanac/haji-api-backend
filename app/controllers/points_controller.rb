class PointsController < ApiController
  protect_from_forgery with: :null_session

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