
require "aws-sdk-s3"

class HikeRoutesController < ApiController
  before_action :authenticate_user, except: [:index, :show, :nearby]
  
  def index
    hike_routes = HikeRoute
      .left_joins(:points)
      .select('hike_routes.*, COUNT(points.id) AS points_count')
      .group('hike_routes.id')
      .map do |route|
        route.as_json.merge(
          distance: route.distance,
          duration: route.duration,
          calculated_from_points: route.points_count >= 2,
          points_count: route.points_count
        )
      end
    render json: { data: hike_routes, status: 200, message: "Success" }
  end

  def my_routes
    user_routes = @current_user.hike_routes.includes(:points).map do |route|
      route.as_json.merge(
        distance: route.distance,
        duration: route.duration,
        calculated_from_points: route.points.count >= 2,
        points_count: route.points.count
      )
    end
    render json: { data: user_routes, status: 200, message: "Success" }
  end

  def nearby
    lat = params[:lat].to_f
    lng = params[:lng].to_f
    radius = (params[:radius].to_f * 1000)

    Rails.logger.info "Nearby search: lat=#{lat}, lng=#{lng}, radius=#{radius}"

    if lat == 0.0 || lng == 0.0
      render json: { status: 400, message: "Invalid coordinates" }
      return
    end

    @points = Point.near(lat, lng, radius)
    route_ids = @points.pluck(:hike_route_id).uniq

    nearby_routes = HikeRoute
      .where(id: route_ids)
      .left_joins(:points)
      .select('hike_routes.*, COUNT(points.id) AS points_count')
      .group('hike_routes.id')
      .map do |route|
        route.as_json.merge(
          distance: route.distance,
          duration: route.duration,
          calculated_from_points: route.points_count >= 2,
          points_count: route.points_count
        )
      end

    render json: { data: nearby_routes, status: 200, message: "Success" }
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
            distance: hike.display_distance,
            duration: hike.display_duration,
            calculated_from_points: hike.points.count >= 2,
            points_count: hike.points.count,
            image_urls: hike.images.attached? ? hike.images.map { |img|
              presigned_url(img)
            } : [],
            image_ids: hike.images.attached? ? hike.images.map(&:id) : [],
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

    if params[:hike_route][:delete_all_images] == 'true'
      Rails.logger.info "Deleting all images - delete_all_images flag set"
      hike_route.images.purge_later if hike_route.images.attached?
    elsif params[:hike_route][:existing_image_ids].present?
      existing_image_ids = params[:hike_route][:existing_image_ids].map(&:to_i)
      current_image_ids = hike_route.images.attached? ? hike_route.images.map(&:id) : []
      image_ids_to_delete = current_image_ids - existing_image_ids

      if image_ids_to_delete.any?
        hike_route.images.each do |image|
          if image_ids_to_delete.include?(image.id)
            Rails.logger.info "Deleting image with ID: #{image.id}"
            image.purge
          end
        end
      end
    end

    if hike_route.update(hike_params.except(:images, :existing_images, :existing_image_ids, :delete_all_images))
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
      if hike_route.images.attached?
        hike_route.images.purge
      end
      
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
      Rails.logger.info "=== TRACK_POINT DEBUG START ==="
      Rails.logger.info "User ID: #{@current_user.id}"
      Rails.logger.info "Received params: #{params.to_unsafe_h}"
      Rails.logger.info "Route ID param: #{params[:route_id]} (type: #{params[:route_id].class})"
      Rails.logger.info "Latitude: #{params[:latitude]}"
      Rails.logger.info "Longitude: #{params[:longitude]}"
      Rails.logger.info "Timestamp: #{params[:timestamp]}"
      Rails.logger.info "Request time: #{Time.current}"
      
      if params[:route_id].nil? || params[:route_id] == "null"
        Rails.logger.info "Creating NEW route (route_id is nil or null)"
        
        # Use timestamp from browser (user's local time)
        user_time = params[:timestamp].present? ? Time.parse(params[:timestamp]) : Time.current
        formatted_time = user_time.strftime('%d.%m.%Y %H:%M')
        
        hike_route = @current_user.hike_routes.create!(
          title: "Nova ruta #{formatted_time}",
          description: "Automatski kreirana ruta tokom praćenja",
          difficulty: "medium",
          duration: 0,
          distance: 0
        )
        Rails.logger.info "✅ Created new route with ID: #{hike_route.id}, time: #{formatted_time}"
      else
        Rails.logger.info "Using EXISTING route ID: #{params[:route_id]}"
        hike_route = HikeRoute.find(params[:route_id])
        Rails.logger.info "✅ Found existing route: #{hike_route.id}, title: #{hike_route.title}"

        if hike_route.user_id != @current_user.id
          Rails.logger.error "❌ User #{@current_user.id} trying to edit route #{hike_route.id} owned by #{hike_route.user_id}"
          render json: { status: 403, message: "You cannot edit route from another user" }
          return
        end
      end

      # Parse timestamp properly with timezone
      parsed_timestamp = if params[:timestamp].present?
        begin
          # Check if it's a Unix timestamp (number)
          if params[:timestamp].to_s.match?(/^\d+$/)
            Time.zone.at(params[:timestamp].to_i)
          else
            # Try to parse as ISO string
            Time.zone.parse(params[:timestamp])
          end
        rescue ArgumentError => e
          Rails.logger.warn "Invalid timestamp format: #{params[:timestamp]}, error: #{e.message}, using current time"
          Time.current
        end
      else
        Time.current
      end

      Rails.logger.info "Building point for route #{hike_route.id}"
      Rails.logger.info "Point data: lat=#{params[:latitude]}, lng=#{params[:longitude]}, timestamp=#{parsed_timestamp}"
      
      point = hike_route.points.build(
        lat: params[:latitude],
        lng: params[:longitude],
        # accuracy: params[:accuracy],  # TODO: Add after migration
        timestamp: parsed_timestamp
        # user: @current_user  # TODO: Add after migration (currently nil)
      )

      if point.save
        Rails.logger.info "✅ Point saved successfully with ID: #{point.id}"
        Rails.logger.info "Route #{hike_route.id} now has #{hike_route.points.count} points"
        
        Rails.cache.delete("hike:#{hike_route.id}")
        Rails.logger.info "Cache invalidated for route #{hike_route.id}"
        
        if hike_route.points.count >= 2
          old_distance = hike_route.distance
          old_duration = hike_route.duration
          new_distance = hike_route.calculated_distance
          new_duration = hike_route.calculated_duration
          
          Rails.logger.info "Updating route calculations: distance #{old_distance} → #{new_distance}, duration #{old_duration} → #{new_duration}"
          
          hike_route.update_columns(
            distance: new_distance,
            duration: new_duration
          )
        end
        
        Rails.logger.info "✅ Sending successful response for route #{hike_route.id}, point #{point.id}"
        Rails.logger.info "=== TRACK_POINT DEBUG END (SUCCESS) ==="
        
        render json: { 
          status: 200, 
          message: "Point saved successfully",
          route_id: hike_route.id, 
          point: {
            id: point.id,
            lat: point.lat,
            lng: point.lng,
            timestamp: point.timestamp
          },
          route_stats: {
            distance: hike_route.distance,
            duration: hike_route.duration,
            points_count: hike_route.points.count,
            calculated_from_points: hike_route.points.count >= 2
          }
        }
      else
        Rails.logger.error "❌ Failed to save point: #{point.errors.full_messages}"
        Rails.logger.info "=== TRACK_POINT DEBUG END (FAILED) ==="
        
        render json: { 
          status: 422, 
          message: "Failed to save point",
          errors: point.errors.full_messages
        }
      end
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "❌ Route not found: #{e.message}"
      Rails.logger.info "=== TRACK_POINT DEBUG END (NOT FOUND) ==="
      render json: { status: 404, message: "Route not found" }
    rescue => e
      Rails.logger.error "❌ Error in track_point: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join('\n')}"
      Rails.logger.info "=== TRACK_POINT DEBUG END (ERROR) ==="
      render json: { status: 500, message: "Internal server error" }
    end
  end
  
  # Finalize route calculations when tracking is stopped
  def finalize
    route = @current_user.hike_routes.find_by(id: params[:id])
    
    if route.nil?
      render json: { status: 404, message: "Route not found or you don't have permission to finalize it" }
      return
    end

    if route.finalize_route!
      render json: { 
        status: 200, 
        message: "Route finalized successfully",
        data: {
          id: route.id,
          distance: route.distance,
          duration: route.duration,
          points_count: route.points.count
        }
      }
    else
      render json: { 
        status: 400, 
        message: "Cannot finalize route: need at least 2 GPS points" 
      }
    end
  end
  
  private

  def hike_params
    params.require(:hike_route).permit(:title, :description, :duration, :difficulty, :distance, :location_latitude, :location_longitude, :best_time_to_visit, :delete_all_images, images: [], existing_images: [], existing_image_ids: [])
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