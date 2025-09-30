# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Only seed if no data exists to avoid duplicates
if PromptEngine::Setting.count == 0
  # Create a default PromptEngine settings record for production
  PromptEngine::Setting.create!(
    openai_api_key: nil, # Will be set via environment variable
    anthropic_api_key: nil,
    preferences: {}
  )

  puts "✅ Created default PromptEngine settings"
else
  puts "⏭️  PromptEngine settings already exist, skipping seed"
end

puts "🌱 Database seeded successfully!"