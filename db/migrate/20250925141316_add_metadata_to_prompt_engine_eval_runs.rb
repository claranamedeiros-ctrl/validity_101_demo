class AddMetadataToPromptEngineEvalRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :prompt_engine_eval_runs, :metadata, :json, default: {}
  end
end
