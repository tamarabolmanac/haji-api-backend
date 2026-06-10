class ReportsController < ApiController
  before_action :authenticate_user

  def create
    report = Report.new(
      reporter: @current_user,
      hike_route_id: params[:hike_route_id],
      reported_user_id: params[:reported_user_id],
      reason: params[:reason],
      details: params[:details]
    )

    if report.save
      render json: { status: 200, message: "Prijava je poslata. Hvala što pomažeš da zajednica bude bezbedna." }
    else
      render json: { status: 422, message: report.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end
end
