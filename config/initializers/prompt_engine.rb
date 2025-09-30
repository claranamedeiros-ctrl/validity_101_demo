# Configure RubyLLM
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
end

Rails.application.config.to_prepare do
  PromptEngine::ApplicationController.class_eval do
    http_basic_authenticate_with(
      name: Rails.application.credentials.prompt_engine_username || "admin",
      password: Rails.application.credentials.prompt_engine_password || "secret123"
    )
  end
end