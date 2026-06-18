ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# JwtAuthenticator čita ENV["SECRET_KEY_BASE"] — u testu nije postavljen,
# pa ga vežemo za app secret da enkodiranje/dekodiranje tokena radi.
ENV["SECRET_KEY_BASE"] ||= Rails.application.secret_key_base

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
