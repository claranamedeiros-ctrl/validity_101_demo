# Override PromptEngine gem controller to fix PostgreSQL compatibility
module PromptEngine
  class EvaluationsController < ApplicationController
    layout "prompt_engine/admin"

    def index
      # FIXED: Remove .distinct because PostgreSQL can't use DISTINCT with JSON columns
      # Use select('DISTINCT ON (id)') instead for PostgreSQL compatibility
      @prompts_with_eval_sets = Prompt.select('DISTINCT ON (prompt_engine_prompts.id) prompt_engine_prompts.*')
        .joins(:eval_sets)
        .includes(eval_sets: [ :eval_runs ])
        .order('prompt_engine_prompts.id, prompt_engine_prompts.name')

      # Calculate overall statistics
      @total_eval_sets = EvalSet.count
      @total_eval_runs = EvalRun.count
      @total_test_cases = TestCase.count

      # Recent activity
      @recent_runs = EvalRun.includes(:eval_set)
        .order(created_at: :desc)
        .limit(10)
    end
  end
end
