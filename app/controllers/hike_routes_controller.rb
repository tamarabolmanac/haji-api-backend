
class HikeRoutesController < ApiController
  include Rails.application.routes.url_helpers
  before_action :authenticate_user, except: [:index, :show]
  
  def index
    hike_routes = HikeRoute.all

    render json: { data: hike_routes, status: 200, message: "Success" }
  end

  def my_routes
    Rails.logger.info "Current user: #{@current_user.inspect}"
    user_routes = @current_user.hike_routes
    Rails.logger.info "User routes count: #{user_routes.count}"
    Rails.logger.info "User routes: #{user_routes.inspect}"

    render json: { data: user_routes, status: 200, message: "Success" }
  end

  def create
    @hike_route = @current_user.hike_routes.build(hike_params.except(:images))
  
    if @hike_route.save
      if params[:hike_route][:images].present?
        params[:hike_route][:images].each do |img|
          @hike_route.images.attach(img)
        end
      end
  
      render json: {
        id: @hike_route.id
      }, status: :created
    else
      render json: { status: 500, message: "Server error" }
    end
  end
  
  
  def show
    hike = HikeRoute.find_by(id: params[:id])
  
    if hike
      render json: {
        data: hike.as_json.merge(
          image_urls: hike.images.attached? ? hike.images.map { |img|
            presigned_url(img)
          } : []
        ),
        status: 200,
        message: "Success"
      } 
    else
      render json: { status: 404, message: "Route not found" }
    end
  end

  private

  def hike_params
    params.require(:hike_route).permit(:title, :description, :duration, :difficulty, :distance, :location_latitude, :location_longitude, :best_time_to_visit, images: [])
  end

  def presigned_url(image)
    s3 = Aws::S3::Resource.new(
      access_key_id: ENV['R2_ACCESS_KEY'],
      secret_access_key: ENV['R2_SECRET_KEY'],
      endpoint: ENV['R2_ENDPOINT'],
      region: ENV['R2_REGION'] || 'auto'
    )
    
    obj = s3.bucket(ENV['R2_BUCKET_NAME']).object(image.key)
    obj.presigned_url(:get, expires_in: 15 * 60)
  end
end