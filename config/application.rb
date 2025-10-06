# Cache bust: 2025-10-01-11:00
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

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Active Record Encryption - MUST be here in application.rb, not production.rb
    # PromptEngine gem needs this BEFORE environment configs load
    # Force redeploy: 2025-10-06 13:45
    config.active_record.encryption.primary_key = ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'] || ('productionkey' * 4)
    config.active_record.encryption.deterministic_key = ENV['ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY'] || ('deterministic' * 4)
    config.active_record.encryption.key_derivation_salt = ENV['ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT'] || ('saltproduction' * 4)
  end
end
