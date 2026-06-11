require "aws-sdk-s3"

class ProtectedAreasController < ApiController
  before_action :authenticate_user, only: [:create, :update, :destroy]
  before_action :require_admin,     only: [:create, :update, :destroy]
  before_action :set_area,          only: [:show, :update, :destroy]

  def index
    areas = ProtectedArea.order(:name).map { |a| serialize(a) }
    render json: areas
  end

  def show
    render json: serialize(@area)
  end

  def create
    area = ProtectedArea.new(area_params)
    if area.save
      area.image.attach(params[:image]) if params[:image].present?
      render json: serialize(area), status: :created
    else
      render json: { errors: area.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @area.update(area_params)
      @area.image.attach(params[:image]) if params[:image].present?
      render json: serialize(@area)
    else
      render json: { errors: @area.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @area.image.purge_later if @area.image.attached?
    @area.destroy
    render json: { message: "Obrisano." }
  end

  private

  def set_area
    @area = ProtectedArea.find(params[:id])
  end

  def area_params
    params.permit(:name, :area_type, :lat, :lon, :description, :legacy_image_path)
  end

  def serialize(area)
    {
      id:          area.id,
      name:        area.name,
      type:        area.area_type,
      lat:         area.lat&.to_f,
      lon:         area.lon&.to_f,
      description: area.description,
      image:       image_url_for(area),
    }
  end

  def image_url_for(area)
    if area.image.attached?
      obj = s3_resource.bucket(ENV['R2_BUCKET_NAME']).object(area.image.blob.key)
      obj.presigned_url(:get, expires_in: 15 * 60)
    elsif area.legacy_image_path.present?
      area.legacy_image_path
    end
  end

  def s3_resource
    @s3_resource ||= Aws::S3::Resource.new(
      access_key_id:     ENV['R2_ACCESS_KEY'],
      secret_access_key: ENV['R2_SECRET_KEY'],
      endpoint:          ENV['R2_ENDPOINT'],
      region:            ENV['R2_REGION'] || 'auto'
    )
  end

  def require_admin
    render json: { error: 'Forbidden' }, status: :forbidden unless @current_user&.role == 'admin'
  end
end
