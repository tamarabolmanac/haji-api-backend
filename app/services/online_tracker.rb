class OnlineTracker
  REDIS_KEY = "online_users"

  def self.redis
    if ENV["REDIS_WRITE_URL"].present?
      @redis_pool ||= ConnectionPool.new(size: Integer(ENV.fetch("REDIS_POOL_SIZE", 5)), timeout: 2) do
        Redis.new(url: ENV["REDIS_WRITE_URL"])
      end
    else
      Rails.cache.redis
    end
  end

  def self.add(user_id)
    redis.with { |conn| conn.sadd(REDIS_KEY, user_id) }
  rescue => e
    Rails.logger.warn "OnlineTracker add failed: #{e.class} #{e.message}"
    nil
  end

  def self.remove(user_id)
    redis.with { |conn| conn.srem(REDIS_KEY, user_id) }
  rescue => e
    Rails.logger.warn "OnlineTracker remove failed: #{e.class} #{e.message}"
    nil
  end

  def self.list
    redis.with { |conn| conn.smembers(REDIS_KEY).map(&:to_i) }
  rescue => e
    Rails.logger.warn "OnlineTracker list failed: #{e.class} #{e.message}"
    []
  end
end
