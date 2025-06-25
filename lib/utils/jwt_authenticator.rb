require 'jwt'
module Utils
  class JwtAuthenticator
    def initialize
      @secret_key = ENV['SECRET_KEY_BASE']
    end
    
    def encode(user)
      payload = {
        user_id: user.id,
        exp: Time.now.to_i + 3600
      }
      JWT.encode(payload, @secret_key, 'HS256')
    end
    
    def decode(token)
      JWT.decode(token, @secret_key, true, { algorithm: 'HS256' })
    end
  end
end
