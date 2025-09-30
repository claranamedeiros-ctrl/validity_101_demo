# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database for patent validity analysis system..."

# Create default PromptEngine settings
if PromptEngine::Setting.count == 0
  PromptEngine::Setting.create!(
    openai_api_key: nil, # Will be set via environment variable
    anthropic_api_key: nil,
    preferences: {}
  )
  puts "✅ Created default PromptEngine settings"
else
  puts "⏭️  PromptEngine settings already exist, skipping"
end

# Create the main prompt for patent validity analysis
prompt = PromptEngine::Prompt.find_or_create_by(id: 1) do |p|
  p.title = "Patent Validity Analysis"
  p.description = "AI-powered patent validity analysis using Alice Test methodology"
  p.content = <<~PROMPT
    You are a patent validity analysis expert. Analyze the following patent claim for validity under 35 USC 101 using the Alice Test methodology.

    Patent Number: {{patent_number}}
    Claim Number: {{claim_number}}
    Claim Text: {{claim_text}}
    Abstract: {{abstract}}

    Provide a detailed analysis including:
    1. Subject matter eligibility under 35 USC 101
    2. Abstract idea identification
    3. Inventive concept analysis
    4. Overall validity assessment with score (0-100)

    Format your response as structured JSON.
  PROMPT
end

# Create the eval set for patent validity test cases
eval_set = PromptEngine::EvalSet.find_or_create_by(id: 2) do |es|
  es.prompt = prompt
  es.name = "Patent Validity Test Cases"
  es.description = "Test cases for patent validity analysis covering various patent types and claims"
end

puts "✅ Created PromptEngine::Prompt: #{prompt.title}"
puts "✅ Created PromptEngine::EvalSet: #{eval_set.name}"

# Create sample evaluation data for demo
if defined?(PromptEngine::Eval) && PromptEngine::Eval.count == 0
  puts "Creating sample evaluation data..."

  PromptEngine::Eval.create!(
    eval_set: eval_set,
    input_data: {
      patent_number: "US10123456B2",
      claim_number: 1,
      claim_text: "A method of processing data using a computer...",
      abstract: "A system and method for processing data..."
    }.to_json,
    expected_output: "Sample expected validity analysis output",
    metadata: { created_for: "demo", source: "seed_data" }.to_json
  )

  puts "✅ Created sample evaluation data"
end

puts "🎉 Database seeding completed!"
puts "Your patent validity analysis system is ready!"
puts "Access it at: /prompt_engine"