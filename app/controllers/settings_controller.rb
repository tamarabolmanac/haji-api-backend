class SettingsController < ApiController
  before_action :authenticate_user, only: [:update]
  before_action :require_admin,     only: [:update]

  # GET /settings — javno; vraća sve flagove koje front koristi
  def index
    render json: {
      show_priroda_srbije: AppSetting.flag("show_priroda_srbije", default: false),
    }
  end

  # PATCH /admin/settings — admin menja flag
  def update
    key = params[:key].to_s
    allowed = %w[show_priroda_srbije]
    unless allowed.include?(key)
      render json: { error: "Nepoznata postavka." }, status: :unprocessable_entity
      return
    end
    AppSetting.set(key, params[:value])
    render json: { key: key, value: AppSetting.flag(key) }
  end

  private

  def require_admin
    render json: { error: "Forbidden" }, status: :forbidden unless @current_user&.role == "admin"
  end
end
