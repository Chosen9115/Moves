require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Moves
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Day boundaries (e.g. the /api/v1/today endpoint) follow this zone. Defaults
    # to UTC; set MOVES_TIME_ZONE (a valid ActiveSupport::TimeZone name, e.g.
    # "Eastern Time (US & Canada)") on the server so "today" matches your locale.
    config.time_zone = ENV.fetch("MOVES_TIME_ZONE", "UTC")

    # config.eager_load_paths << Rails.root.join("extras")
  end
end
