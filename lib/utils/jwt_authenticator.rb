require 'jwt'
module Utils
  class JwtAuthenticator
    def initialize
      @secret_key = ENV['SECRET_KEY_BASE']
    end
    
    def encode(user)
      payload = {
        user_id: user.id,
        exp: Time.now.to_i + (2 * 24 * 3600) # 2 days = 2 * 24 * 3600 seconds
      }
      JWT.encode(payload, @secret_key, 'HS256')
    end
    
    def decode(token)
      JWT.decode(token, @secret_key, true, { algorithm: 'HS256' })
    end
  end
end
