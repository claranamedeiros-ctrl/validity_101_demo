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
  p.name = "Patent Validity Analysis"
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

puts "✅ Created PromptEngine::Prompt: #{prompt.name}"
puts "✅ Created PromptEngine::EvalSet: #{eval_set.name}"

# Create test cases from CSV files
require 'csv'

if PromptEngine::TestCase.where(eval_set: eval_set).count == 0
  puts "Creating patent validity test cases from CSV files..."

  # Read input data and ground truth
  inputs_file = Rails.root.join('inputs', 'validity_inputs_test.csv')
  ground_truth_file = Rails.root.join('groundt', 'gt_aligned_normalized_test.csv')

  if File.exist?(inputs_file) && File.exist?(ground_truth_file)
    # Load ground truth data into hash for lookup
    ground_truth = {}
    CSV.foreach(ground_truth_file, headers: true) do |row|
      key = "#{row['patent_number']}_#{row['claim_number']}"
      ground_truth[key] = row['gt_overall_eligibility']
    end

    # Create test cases from input data
    test_cases_created = 0
    CSV.foreach(inputs_file, headers: true) do |row|
      key = "#{row['patent_number']}_#{row['claim_number']}"
      expected_output = ground_truth[key] || 'unknown'

      PromptEngine::TestCase.create!(
        eval_set: eval_set,
        input_variables: {
          patent_id: row['patent_number'],
          claim_number: row['claim_number'].to_i,
          claim_text: row['claim_text'],
          abstract: row['abstract']
        }.to_json,
        expected_output: expected_output,
        description: "#{row['patent_number']} Claim #{row['claim_number']}"
      )

      test_cases_created += 1
    end

    puts "✅ Created #{test_cases_created} patent validity test cases"
  else
    puts "⚠️  CSV files not found, creating sample test case instead"

    PromptEngine::TestCase.create!(
      eval_set: eval_set,
      input_variables: {
        patent_id: "US6128415A",
        claim_number: 1,
        claim_text: "A device profile for describing properties of a device in a digital image reproduction system...",
        abstract: "Device profiles conventionally describe..."
      }.to_json,
      expected_output: "ineligible",
      description: "US6128415A Claim 1 - Sample Test Case"
    )

    puts "✅ Created sample test case"
  end
else
  puts "⏭️  Test cases already exist, skipping"
end

puts "🎉 Database seeding completed!"
puts "Your patent validity analysis system is ready!"
puts "Access it at: /prompt_engine"