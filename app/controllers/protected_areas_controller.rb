class ProtectedAreasController < ActionController::API
  def index
    json_path = Rails.root.join('db', 'seeds', 'protected_areas.json')
    areas = JSON.parse(File.read(json_path))
    render json: areas
  end
end
