# Returns 404 immediately for common bot/scanner paths (WordPress, xmlrpc, etc.)
# so they never hit Rails routing or the database. Add to config/application.rb.
class BlockBotProbes
  BOT_PATTERNS = %w[
    wp-includes
    wlwmanifest
    xmlrpc.php
    xmlrpc
    wp-admin
    wp-content
    wp-login
    .env
    wp-config
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["REQUEST_URI"].to_s.split("?").first.to_s.downcase
    return [404, { "Content-Type" => "text/plain", "Content-Length" => "0" }, []] if bot_path?(path)
    @app.call(env)
  end

  private

  def bot_path?(path)
    # Normalize double slashes
    path = path.gsub(%r{/+}, "/")
    BOT_PATTERNS.any? { |p| path.include?(p) }
  end
end
