
require "aws-sdk-s3"
require "set"

class HikeRoutesController < ApiController
  # Sve akcije sada zahtevaju autentikaciju — i index/show/nearby
  before_action :authenticate_user
  
  def index
    # Allow optional authentication so da možemo da filtriramo po praćenim korisnicima
    authenticate_token

    scope = HikeRoute.left_joins(:points)
                     .includes(:user, images_attachments: :blob)
                     .select('hike_routes.*, COUNT(points.id) AS points_count')
                     .group('hike_routes.id')

    if params[:scope] == "following"
      unless @current_user
        render json: { status: 401, message: "Morate biti prijavljeni da biste videli feed ruta korisnika koje pratite." }, status: :unauthorized
        return
      end

      followed_ids = @current_user.following.select(:id)
      # Po default-u u feed dodajemo i sopstvene rute
      scope = scope.where(user_id: followed_ids).or(scope.where(user_id: @current_user.id))
    end

    hike_routes = scope.map do |route|
      author = route.user

      route.as_json.merge(
        distance: route.distance,
        duration: route.duration,
        calculated_from_points: route.points_count >= 2,
        points_count: route.points_count,
        thumbnail_url: route.images.attached? ? presigned_url(route.images.first) : nil,
        author: author ? {
          id: author.id,
          name: author.name,
          avatar_url: author.avatar&.attached? ? avatar_url_for(author) : nil
        } : nil
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

  # Nearby lookup using overpass_routes_dsl gem.
  # Expects lat, lon, radius (km), mode, country.
  def nearby_overpass
    lat = Float(params[:lat])
    lon = Float(params[:lon])
    radius_km = Float(params[:radius])
    radius_m = (radius_km * 1000).round
    mode = params[:mode].to_s.presence || "peaks"
    country = params[:country].to_s.presence || "Serbia"

    supported_modes = %w[peaks hiking_paths]
    unless supported_modes.include?(mode)
      render json: { status: 400, message: "Unsupported mode. Allowed: #{supported_modes.join(', ')}" }, status: :bad_request
      return
    end

    query = OverpassRoutesDsl.build do
      country country
      mode mode.to_sym
      around lat, lon, radius_m: radius_m
    end

    client = OverpassRoutesDsl::Client.new
    result = client.execute(query)

    Rails.logger.info("[NearbyOverpass] params=#{{
      lat: lat,
      lon: lon,
      radius_km: radius_km,
      radius_m: radius_m,
      mode: mode,
      country: country
    }.to_json}")
    Rails.logger.info("[NearbyOverpass] result_elements=#{result.fetch('elements', []).size}")

    render json: {
      status: 200,
      message: "Success",
      query: query,
      data: result
    }
  rescue ArgumentError, TypeError
    render json: { status: 400, message: "Invalid parameters (lat, lon, radius are required numeric values)." }, status: :bad_request
  rescue OverpassRoutesDsl::ValidationError => e
    render json: { status: 422, message: e.message }, status: :unprocessable_entity
  rescue OverpassRoutesDsl::Error => e
    Rails.logger.error("[NearbyOverpass] Overpass error: #{e.message}")
    render json: { status: 502, message: "Overpass request failed" }, status: :bad_gateway
  rescue StandardError => e
    Rails.logger.error("[NearbyOverpass] Unexpected error: #{e.class} #{e.message}\n#{e.backtrace&.first(8)&.join("\n")}")
    render json: { status: 500, message: "Internal server error" }, status: :internal_server_error
  end

  def create
    @hike_route = @current_user.hike_routes.build(hike_params.except(:images))
  
    if @hike_route.save
      if params[:hike_route][:images].present?
        params[:hike_route][:images].each do |img|
          @hike_route.images.attach(process_upload_image(img))
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
    hike = HikeRoute.includes(:points, :user).find_by(id: params[:id])
    if hike
      cache_key = "hike:#{hike.id}"
      data = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
        author = hike.user
        author_payload = author ? {
          id: author.id,
          name: author.name,
          avatar_url: author.avatar&.attached? ? avatar_url_for(author) : nil
        } : nil

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
            end,
            author: author_payload
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
          hike_route.images.attach(process_upload_image(img))
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
      # Brišemo rutu odmah; slike sa R2 idu u pozadinu da odgovor ne visi
      hike_route.images.purge_later if hike_route.images.attached?
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
          distance: 0,
          status: "tracking"
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

  # Bulk insert tačaka (offline queue / loš signal). Idempotentno po (hike_route_id, client_uuid).
  # Telo: { "route_id": <opciono>, "points": [ { "lat", "lng", "timestamp?", "accuracy?", "client_uuid?" }, ... ] }
  def track_points_bulk
    permitted = bulk_track_params
    points_data = permitted[:points]

    unless points_data.is_a?(Array) && points_data.any?
      render json: { status: 400, message: "points mora biti ne-prazan niz" }, status: :bad_request
      return
    end

    if points_data.size > 200
      render json: { status: 400, message: "Najviše 200 tačaka po zahtevu" }, status: :bad_request
      return
    end

    raw_first = points_data.first
    first_hash = raw_first.respond_to?(:to_unsafe_h) ? raw_first.to_unsafe_h : raw_first.stringify_keys
    first_ts = first_hash["timestamp"] || first_hash[:timestamp]

    hike_route = nil
    rid = permitted[:route_id]

    unless rid.nil? || rid.to_s.strip.empty? || rid.to_s == "null"
      hike_route = HikeRoute.find_by(id: rid)
      if hike_route.nil?
        render json: { status: 404, message: "Ruta nije pronađena" }, status: :not_found
        return
      end
      if hike_route.user_id != @current_user.id
        render json: { status: 403, message: "You cannot edit route from another user" }, status: :forbidden
        return
      end
    end

    created_count = 0
    skipped_duplicate = 0

    ActiveRecord::Base.transaction do
      hike_route ||= create_tracking_route_for_bulk!(first_ts)

      seen_uuids = Set.new

      points_data.each_with_index do |raw, index|
        p = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.stringify_keys
        lat = p["lat"] || p[:lat]
        lng = p["lng"] || p[:lng]
        if lat.nil? || lng.nil?
          raise ArgumentError, "Tačka ##{index + 1}: lat i lng su obavezni"
        end

        parsed_ts = parse_point_timestamp(p["timestamp"] || p[:timestamp])
        accuracy = p["accuracy"] || p[:accuracy]
        cu = (p["client_uuid"] || p[:client_uuid]).to_s.presence

        if cu.present? && seen_uuids.include?(cu)
          next
        end
        seen_uuids.add(cu) if cu.present?

        attrs = {
          lat: lat.to_f,
          lng: lng.to_f,
          timestamp: parsed_ts
        }
        attrs[:accuracy] = accuracy.to_f unless accuracy.nil? || accuracy == ""

        if cu.present?
          point = hike_route.points.find_or_initialize_by(client_uuid: cu)
          if point.persisted?
            skipped_duplicate += 1
            next
          end
          point.assign_attributes(attrs)
          point.save!
        else
          hike_route.points.create!(attrs)
        end
        created_count += 1
      end

      Rails.cache.delete("hike:#{hike_route.id}")

      if hike_route.points.count >= 2
        hike_route.update_columns(
          distance: hike_route.calculated_distance,
          duration: hike_route.calculated_duration
        )
      end
    end

    hike_route.reload

    render json: {
      status: 200,
      message: "Tačke obrađene",
      route_id: hike_route.id,
      created: created_count,
      skipped_duplicate: skipped_duplicate,
      points_count: hike_route.points.count,
      route_stats: {
        distance: hike_route.distance,
        duration: hike_route.duration,
        calculated_from_points: hike_route.points.count >= 2
      }
    }
  rescue ArgumentError => e
    render json: { status: 400, message: e.message }, status: :bad_request
  rescue ActiveRecord::RecordInvalid => e
    render json: { status: 422, message: e.message, errors: e.record&.errors&.full_messages }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "track_points_bulk: #{e.class} #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}"
    render json: { status: 500, message: "Greška pri snimanju tačaka" }, status: :internal_server_error
  end

  # Kreiranje potpuno nove rute za snimanje putanje (pre prvog GPS point-a)
  def start_new
    # Use timestamp from server time for default title
    user_time = Time.current
    formatted_time = user_time.strftime('%d.%m.%Y %H:%M')

    hike_route = @current_user.hike_routes.create!(
      title: "Nova ruta #{formatted_time}",
      description: "Automatski kreirana ruta tokom praćenja",
      difficulty: "medium",
      duration: 0,
      distance: 0,
      status: "tracking"
    )

    render json: {
      status: 200,
      message: "Route created for tracking",
      id: hike_route.id
    }
  rescue => e
    Rails.logger.error "Error in start_new: #{e.message}"
    render json: { status: 500, message: "Internal server error" }, status: :internal_server_error
  end
  
  # Explicitno označi rutu kao "tracking" kada korisnik krene sa snimanjem
  def start_tracking
    route = @current_user.hike_routes.find_by(id: params[:id])

    if route.nil?
      render json: { status: 404, message: "Route not found or you don't have permission to start tracking" }
      return
    end

    route.update_column(:status, "tracking")

    render json: {
      status: 200,
      message: "Route tracking started",
      data: {
        id: route.id,
        status: route.status
      }
    }
  end
  
  # Finalize route when tracking is stopped
  def finalize
    route = @current_user.hike_routes.find_by(id: params[:id])
    
    if route.nil?
      render json: { status: 404, message: "Route not found or you don't have permission to finalize it" }
      return
    end

    if route.points.count >= 2
      # Izračunaj distancu/vreme iz tačaka i označi kao finalized
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
        render json: { status: 400, message: "Cannot finalize route" }
      end
    else
      # Premalo tačaka za proračun, ali svejedno je zaključavamo – bez opcije nastavka
      route.update_column(:status, "finalized")
      render json: {
        status: 200,
        message: "Route finalized without GPS stats (premalo tačaka)",
        data: {
          id: route.id,
          distance: route.distance,
          duration: route.duration,
          points_count: route.points.count
        }
      }
    end
  end
  
  private

  def bulk_track_params
    params.permit(:route_id, points: [:lat, :lng, :accuracy, :timestamp, :client_uuid])
  end

  def parse_point_timestamp(value)
    return Time.current if value.blank?

    begin
      if value.to_s.match?(/^\d+$/)
        Time.zone.at(value.to_i)
      else
        Time.zone.parse(value.to_s)
      end
    rescue ArgumentError => e
      Rails.logger.warn "Invalid timestamp format: #{value.inspect}, error: #{e.message}, using current time"
      Time.current
    end
  end

  def create_tracking_route_for_bulk!(first_timestamp)
    user_time = first_timestamp.present? ? parse_point_timestamp(first_timestamp) : Time.current
    formatted_time = user_time.strftime("%d.%m.%Y %H:%M")
    @current_user.hike_routes.create!(
      title: "Nova ruta #{formatted_time}",
      description: "Automatski kreirana ruta tokom praćenja",
      difficulty: "medium",
      duration: 0,
      distance: 0,
      status: "tracking"
    )
  end

  def hike_params
    params.require(:hike_route).permit(:title, :description, :duration, :difficulty, :distance, :location_latitude, :location_longitude, :best_time_to_visit, :delete_all_images, images: [], existing_images: [], existing_image_ids: [])
  end

  def presigned_url(image)
    obj = s3_resource.bucket(ENV['R2_BUCKET_NAME']).object(image.key)
    obj.presigned_url(:get, expires_in: 15 * 60)
  end

  def avatar_url_for(user)
    return nil unless user.avatar.attached?
    begin
      obj = s3_resource.bucket(ENV['R2_BUCKET_NAME']).object(user.avatar.blob.key)
      obj.presigned_url(:get, expires_in: 15 * 60)
    rescue => _e
      nil
    end
  end

  # Resize i WebP pri uploadu – manji fajlovi, brže učitavanje
  def process_upload_image(upload)
    require "image_processing/mini_magick"
    source = upload.respond_to?(:tempfile) ? upload.tempfile : upload
    processed = ImageProcessing::MiniMagick
      .source(source)
      .resize_to_limit(1600, 1600)
      .convert("webp")
      .saver(quality: 82)
      .call
    {
      io: File.open(processed.path),
      filename: (upload.respond_to?(:original_filename) ? File.basename(upload.original_filename, ".*") : "image") + ".webp",
      content_type: "image/webp"
    }
  rescue => e
    Rails.logger.error "Image process on upload failed: #{e.message}"
    upload
  end

  # Memoizovani S3 resource – kreira se samo jednom po requestu
  def s3_resource
    @s3_resource ||= Aws::S3::Resource.new(
      access_key_id: ENV['R2_ACCESS_KEY'],
      secret_access_key: ENV['R2_SECRET_KEY'],
      endpoint: ENV['R2_ENDPOINT'],
      region: ENV['R2_REGION'] || 'auto'
    )
  end
end