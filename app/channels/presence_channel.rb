class PresenceChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "✅ SUBSCRIBED to PresenceChannel"
    stream_from "presence"

    ActionCable.server.broadcast(
      "presence",
      {
        event: "join",
        user: {
          id: current_user.id,
          name: current_user.name,
          email: current_user.email,
          avatar_url: avatar_url_for(current_user)
        }
      }
    )
  end

  def unsubscribed
    ActionCable.server.broadcast(
      "presence",
      {
        event: "leave",
        user: current_user.id
      }
    )
    Rails.logger.info "❌ UNSUBSCRIBED from PresenceChannel"
  end

  private

  def avatar_url_for(user)
    return nil unless user.respond_to?(:avatar) && user.avatar.attached?
    begin
      s3 = Aws::S3::Resource.new(
        access_key_id: ENV['R2_ACCESS_KEY'],
        secret_access_key: ENV['R2_SECRET_KEY'],
        endpoint: ENV['R2_ENDPOINT'],
        region: ENV['R2_REGION'] || 'auto'
      )
      obj = s3.bucket(ENV['R2_BUCKET_NAME']).object(user.avatar.blob.key)
      obj.presigned_url(:get, expires_in: 15 * 60)
    rescue => _e
      path = Rails.application.routes.url_helpers.rails_blob_path(user.avatar, only_path: true)
      base = ENV['PUBLIC_API_BASE_URL'].presence || (Rails.env.production? ? 'https://api.hajki.com' : 'http://localhost:3000')
      "#{base}#{path}"
    end
  end
end
