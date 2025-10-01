require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Validity101Demo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Asset pipeline configuration
    config.assets.enabled = true
    config.assets.paths << Rails.root.join('app', 'assets', 'images')
    config.assets.paths << Rails.root.join('app', 'assets', 'stylesheets')
    config.assets.paths << Rails.root.join('app', 'assets', 'javascripts')

    # Add PromptEngine assets paths
    if defined?(PromptEngine)
      engine_root = PromptEngine::Engine.root
      config.assets.paths << engine_root.join('app', 'assets', 'stylesheets')
      config.assets.paths << engine_root.join('app', 'assets', 'images') if Dir.exist?(engine_root.join('app', 'assets', 'images'))
    end

    # CRITICAL: Exclude PromptEngine gem migrations
    # The gem has migrations in wrong order, we use local copies instead
    config.after_initialize do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.migration_context.migrations_paths.delete_if do |path|
          path.include?('prompt_engine') && path.include?('gems')
        end
      end
    end

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end