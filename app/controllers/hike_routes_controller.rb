
require "aws-sdk-s3"

class HikeRoutesController < ApiController
  include Rails.application.routes.url_helpers
  before_action :authenticate_user, except: [:index, :show]
  
  def index
    hike_routes = HikeRoute.includes(:points).all.map do |route|
      route.as_json.merge(
        distance: route.display_distance,
        duration: route.display_duration,
        calculated_from_points: route.points.count >= 2,
        points_count: route.points.count
      )
    end
    render json: { data: hike_routes, status: 200, message: "Success" }
  end

  def my_routes
    Rails.logger.info "Current user: #{@current_user.inspect}"
    user_routes = @current_user.hike_routes.includes(:points).map do |route|
      route.as_json.merge(
        distance: route.display_distance,
        duration: route.display_duration,
        calculated_from_points: route.points.count >= 2,
        points_count: route.points.count
      )
    end
    Rails.logger.info "User routes count: #{user_routes.count}"

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
    hike = HikeRoute.includes(:points).find_by(id: params[:id])

    if hike
      cache_key = "hike:#{hike.id}"
      data = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do

        {
          data: hike.as_json.merge(
            # Override distance and duration with calculated values
            distance: hike.display_distance,
            duration: hike.display_duration,
            # Add metadata about calculation
            calculated_from_points: hike.points.count >= 2,
            points_count: hike.points.count,
            image_urls: hike.images.attached? ? hike.images.map { |img|
              presigned_url(img)  # tvoj metod za AWS R2
            } : [],
            points: hike.points.order(:timestamp).map do |p|
              { lat: p.lat, lng: p.lng, timestamp: p.timestamp }
            end
          ),
          status: 200,
          message: "Success"
        }
      end

      render json: data
    else
      render json: { status: 404, message: "Route not found" }
    end
  end

  def update
    hike_route = @current_user.hike_routes.find_by(id: params[:id])
    
    if hike_route.nil?
      render json: { status: 404, message: "Route not found or you don't have permission to edit it" }
      return
    end

    # Handle image updates
    if params[:hike_route][:existing_images].present?
      # Keep only the existing images that are still in the list
      # This effectively removes images that were deleted in the frontend
      existing_image_urls = params[:hike_route][:existing_images]
      
      # For now, we'll just log this - implementing selective image deletion 
      # would require more complex logic to track which images to keep/delete
      Rails.logger.info "Existing images to keep: #{existing_image_urls}"
    end

    # Update route attributes
    if hike_route.update(hike_params.except(:images, :existing_images))
      
      # Handle new image uploads (same as create method)
      if params[:hike_route][:images].present?
        params[:hike_route][:images].each do |img|
          hike_route.images.attach(img)
        end
      end

      render json: { 
        status: 200, 
        message: "Route updated successfully",
        data: hike_route.as_json.merge(
          image_urls: hike_route.images.attached? ? hike_route.images.map { |img|
            presigned_url(img)
          } : []
        )
      }
    else
      render json: { 
        status: 422, 
        message: "Failed to update route",
        errors: hike_route.errors.full_messages
      }
    end
  rescue => e
    Rails.logger.error "Error updating route: #{e.message}"
    render json: { status: 500, message: "Server error while updating route" }
  end

  def destroy
    hike_route = @current_user.hike_routes.find_by(id: params[:id])
    
    if hike_route
      # Delete associated images from storage
      if hike_route.images.attached?
        hike_route.images.purge
      end
      
      # Delete the route
      hike_route.destroy
      
      render json: { status: 200, message: "Ruta je uspešno obrisana" }
    else
      render json: { status: 404, message: "Ruta nije pronađena ili nemate dozvolu za brisanje" }
    end
  rescue => e
    Rails.logger.error "Error deleting route: #{e.message}"
    render json: { status: 500, message: "Greška pri brisanju rute" }
  end

  def track_point
    begin
      if params[:route_id].nil? || params[:route_id] == "null"
        # Create new route for tracking
        hike_route = @current_user.hike_routes.create!(
          title: "Nova ruta #{Time.current.strftime('%d.%m.%Y %H:%M')}",
          description: "Automatski kreirana ruta tokom praćenja",
          difficulty: "medium",
          duration: 0,
          distance: 0
        )
        Rails.logger.info "Created new route with ID: #{hike_route.id}"
      else
        # Use existing route
        hike_route = HikeRoute.find(params[:route_id])
        
        # Check if user owns the route
        if hike_route.user_id != @current_user.id
          render json: { status: 403, message: "You cannot edit route from another user" }
          return
        end
      end

      # Create tracking point
      point = hike_route.points.build(
        lat: params[:latitude],
        lng: params[:longitude],
        # accuracy: params[:accuracy],  # TODO: Add after migration
        timestamp: params[:timestamp] || Time.current
        # user: @current_user  # TODO: Add after migration (currently nil)
      )

      if point.save
        Rails.cache.delete("hike:#{hike_route.id}")
        Rails.logger.info "Cache invalidated for route #{hike_route.id}"
        
        # Auto-update route distance and duration if we have enough points
        if hike_route.points.count >= 2
          hike_route.update_columns(
            distance: hike_route.calculated_distance,
            duration: hike_route.calculated_duration
          )
        end
        
        render json: { 
          status: 200, 
          message: "Point saved successfully",
          route_id: hike_route.id,  # Return route_id for frontend
          point: {
            id: point.id,
            lat: point.lat,
            lng: point.lng,
            timestamp: point.timestamp
          },
          # Return updated route stats
          route_stats: {
            distance: hike_route.display_distance,
            duration: hike_route.display_duration,
            points_count: hike_route.points.count,
            calculated_from_points: hike_route.points.count >= 2
          }
        }
      else
        render json: { 
          status: 422, 
          message: "Failed to save point",
          errors: point.errors.full_messages
        }
      end
    rescue ActiveRecord::RecordNotFound
      render json: { status: 404, message: "Route not found" }
    rescue => e
      Rails.logger.error "Error in track_point: #{e.message}"
      render json: { status: 500, message: "Internal server error" }
    end
  end
  

  private

  def hike_params
    params.require(:hike_route).permit(:title, :description, :duration, :difficulty, :distance, :location_latitude, :location_longitude, :best_time_to_visit, images: [], existing_images: [])
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