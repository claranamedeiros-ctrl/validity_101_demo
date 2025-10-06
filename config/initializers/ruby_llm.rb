# Refresh RubyLLM models registry to include latest models like GPT-5
Rails.application.config.after_initialize do
  RubyLLM::Models.refresh!
  Rails.logger.info "RubyLLM models refreshed"
end
