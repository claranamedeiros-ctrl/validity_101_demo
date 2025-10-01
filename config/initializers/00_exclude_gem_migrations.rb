# CRITICAL: This must be the FIRST initializer (prefix with 00_)
#
# PromptEngine gem has broken migration order. We use local copies.
# This initializer excludes the gem's db/migrate path.

Rails.application.config.before_initialize do
  # Find and remove prompt_engine gem migration paths
  if defined?(PromptEngine::Engine)
    gem_migration_path = PromptEngine::Engine.root.join('db', 'migrate').to_s

    # Remove from active_record migration paths
    ActiveRecord::Tasks::DatabaseTasks.migrations_paths.delete(gem_migration_path)
  end
end
