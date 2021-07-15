require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Benchmarkit
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    config.autoload_paths += %W( #{config.root}/lib );
    config.eager_load_paths += %W( #{config.root}/lib );

    config.redis = Redis::Namespace.new("benchmarkit", :redis => Redis.new(host: ENV["REDIS_HOST"], port: ENV["REDIS_PORT"], db: 2));
    config.cache_store = :redis_store, ENV["CACHE_URL"], { expires_in: 90.minutes };
    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
