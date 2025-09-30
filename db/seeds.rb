# Simplified seeds for production deployment
puts "🌱 Seeding database for patent validity analysis system..."

# Create default PromptEngine settings (required for the system to work)
begin
  if PromptEngine::Setting.count == 0
    PromptEngine::Setting.create!(
      openai_api_key: ENV['OPENAI_API_KEY'], # Set from environment variable
      anthropic_api_key: nil,
      preferences: {}
    )
    puts "✅ Created default PromptEngine settings"
  else
    puts "⏭️  PromptEngine settings already exist"
  end
rescue => e
  puts "⚠️  Error creating settings: #{e.message}"
end

puts "🎉 Database seeding completed!"
puts ""
puts "📝 Next steps:"
puts "1. Access your app at the Railway URL"
puts "2. Navigate to /prompt_engine"
puts "3. Create your prompts and evaluation sets manually through the UI"
puts "4. Or run 'rails runner scripts/import_patent_data.rb' to load the 50 patent test cases"
