# CRITICAL: Disable PromptEngine gem migrations
#
# The PromptEngine gem has migrations in the wrong order (CreateEvalTables before CreatePrompts)
# which causes PostgreSQL errors. We've copied all migrations to db/migrate/ with corrected order.
#
# This initializer prevents Rails from loading the gem's broken migrations.

Rails.application.config.to_prepare do
  # Remove prompt_engine gem migrations from ActiveRecord's migration paths
  ActiveRecord::Migrator.migrations_paths.delete_if do |path|
    path.include?('prompt_engine') && path.include?('gems')
  end
end
