require_relative "boot"

require "rails/all"

# Must load before Bundler.require so Sidekiq::ActiveJob is defined when ActiveJob
# adapter loads. Fixes "uninitialized constant Sidekiq::ActiveJob" in production.
# See: https://github.com/sidekiq/sidekiq/issues/6612
require "sidekiq/rails"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module HajkiApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Belgrade"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
