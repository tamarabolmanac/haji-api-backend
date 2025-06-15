
class HikeRoutesController < ApiController
  def index
    hike_routes = HikeRoute.all

    render json: { data: hike_routes, status: 200, message: "Success" }
  end

  def create
    @hike = HikeRoute.new(hike_params)

    if @hike.save
      render json: { status: 200, message: "Success" }
    else
      render json: { status: 500, message: "Server error" }
    end
  end

  def show
    hike = HikeRoute.find_by(id: params[:id])
  
    if hike
      render json: { data: hike, status: 200, message: "Success" }
    else
      render json: { status: 404, message: "Route not found" }
    end
  end

  def hike_params
    params.permit(:title, :description, :duration, :difficulty, :distance, :location_latitude, :location_longitude, :best_time_to_visit)
  end
end