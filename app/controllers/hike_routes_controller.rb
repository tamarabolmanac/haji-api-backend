
class HikeRoutesController < ApiController
  def index
    hike_routes = HikeRoute.all

    render json: { data: hike_routes, status: 200, message: "Success" }
  end

  def create
    puts "TEST"
    puts params

    @hike = HikeRoute.new(hike_params)

    if @hike.save
      render json: { status: 200, message: "Success" }
    else
      render json: { status: 500, message: "Server error" }
    end
  end

  def hike_params
    params.permit(:title, :description)
  end
end