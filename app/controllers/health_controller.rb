class HealthController < ActionController::Base
  def check
    checks = {
      database: database_ok?,
      redis: redis_ok?
    }

    if checks.values.all?
      render json: { status: 'ok', checks: checks }, status: :ok
    else
      render json: { status: 'degraded', checks: checks }, status: :service_unavailable
    end
  end

  private

  def database_ok?
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue => e
    Rails.logger.error("Health check - DB error: #{e.message}")
    false
  end

  def redis_ok?
    redis_url = ENV.fetch('REDIS_URL') { 'redis://redis:6379/1' }
    Redis.new(url: redis_url, timeout: 2).ping == 'PONG'
  rescue => e
    Rails.logger.error("Health check - Redis error: #{e.message}")
    false
  end
end
