module Admin
  class ReportsController < ApiController
    before_action :authenticate_user
    before_action :require_admin

    def index
      reports = Report.includes(:reporter, :reported_user, hike_route: :user)
                      .order(created_at: :desc)
                      .limit(200)

      data = reports.map do |r|
        {
          id: r.id,
          reason: r.reason,
          details: r.details,
          status: r.status,
          created_at: r.created_at,
          reporter: { id: r.reporter_id, name: r.reporter&.name },
          hike_route: r.hike_route ? { id: r.hike_route.id, title: r.hike_route.title, author: r.hike_route.user&.name } : nil,
          reported_user: r.reported_user ? { id: r.reported_user.id, name: r.reported_user.name } : nil
        }
      end

      render json: { data: data, status: 200 }
    end

    def update
      report = Report.find(params[:id])
      if Report::STATUSES.include?(params[:status])
        report.update!(status: params[:status])
        render json: { status: 200, message: "Status ažuriran." }
      else
        render json: { status: 422, message: "Nevažeći status." }, status: :unprocessable_entity
      end
    end

    def destroy_route
      report = Report.find(params[:id])
      route = report.hike_route
      unless route
        render json: { status: 404, message: "Ruta ne postoji ili je već obrisana." }, status: :not_found
        return
      end
      route.images.purge_later if route.images.attached?
      route.destroy
      report.update!(status: "reviewed")
      render json: { status: 200, message: "Ruta je obrisana." }
    end

    private

    def require_admin
      unless @current_user&.role == "admin"
        render json: { status: 403, message: "Pristup dozvoljen samo administratorima." }, status: :forbidden
      end
    end
  end
end
