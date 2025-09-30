# Extend PromptEngine models with custom methods
Rails.application.config.to_prepare do
  PromptEngine::EvalRun.class_eval do
    # Add the metadata attribute to the PromptEngine::EvalRun model
    attribute :metadata, :json, default: {}

    def display_name
      "Run ##{id} - #{created_at.strftime('%m/%d/%Y %H:%M')} (#{status.humanize})"
    end

    def success_rate
      return 0.0 if total_count.to_i == 0
      (passed_count.to_f / total_count * 100).round(2)
    end

    def progress_percent
      metadata&.dig('progress') || (status == 'completed' ? 100 : 0)
    end

    # Override started_at to ensure it's never nil
    def started_at
      super || created_at
    end

    # Override completed_at to return a sensible default for completed runs
    def completed_at
      return super if super.present?
      return updated_at if status == 'completed'
      nil
    end
  end

  # Fix EvalSet grader_config to ensure it's always a Hash
  PromptEngine::EvalSet.class_eval do
    def grader_config
      config = super
      return {} if config.nil?
      return config if config.is_a?(Hash)

      # If it's a string, try to parse it as JSON
      begin
        JSON.parse(config)
      rescue JSON::ParserError
        {}
      end
    end
  end
end