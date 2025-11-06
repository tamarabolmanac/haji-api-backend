class OnlineTracker
  REDIS_KEY = "online_users"

  def self.redis
    Rails.cache.redis
  end

  def self.add(user_id)
    redis.with do |conn|
      conn.sadd(REDIS_KEY, user_id)
    end
  end

  def self.remove(user_id)
    redis.with do |conn|
      conn.srem(REDIS_KEY, user_id)
    end
  end

  def self.list
    redis.with do |conn|
      conn.smembers(REDIS_KEY).map(&:to_i)
    end
  end
end
