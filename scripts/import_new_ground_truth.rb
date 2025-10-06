#!/usr/bin/env ruby
# Import new transformed ground truth data into Rails database
# Run with: railway run rails runner scripts/import_new_ground_truth.rb

require 'csv'

puts "🚀 Starting Ground Truth Import to Database"
puts "=" * 80

# Step 1: Find or create the Validity Analysis prompt
prompt = PromptEngine::Prompt.find_or_create_by!(name: "validity-101-agent") do |p|
  p.description = "AI-powered patent validity analysis using Alice Test methodology"

  # Load system prompt from backend/system.erb
  system_prompt_path = Rails.root.join('backend', 'system.erb')
  if File.exist?(system_prompt_path)
    p.system_message = File.read(system_prompt_path)
    puts "✅ Loaded system prompt from backend/system.erb"
  else
    puts "⚠️  Warning: backend/system.erb not found"
    p.system_message = "You are a patent validity analysis expert."
  end

  # Load user prompt template from backend/user.erb
  user_prompt_path = Rails.root.join('backend', 'user.erb')
  if File.exist?(user_prompt_path)
    p.content = File.read(user_prompt_path)
    puts "✅ Loaded user prompt from backend/user.erb"
  else
    p.content = <<~PROMPT
      Patent number: {{patent_id}}
      Claim number: {{claim_number}}
      Claim text: {{claim_text}}
      Abstract: {{abstract}}
    PROMPT
  end

  p.model = "gpt-4o"
  p.temperature = 0.1
  p.max_tokens = 1200
  p.status = "active"
end

puts "✅ Prompt: #{prompt.name} (ID: #{prompt.id})"

# Step 2: Create evaluation set
eval_set = PromptEngine::EvalSet.find_or_create_by!(prompt: prompt, name: "Patent Validity Test Cases - 50 Patents") do |es|
  es.description = "Test cases for patent validity analysis covering 50 patents with full claim text and abstracts"
  es.grader_type = "exact_match"
end

puts "✅ Eval Set: #{eval_set.name} (ID: #{eval_set.id})"

# Step 3: Clear existing test cases
old_count = eval_set.test_cases.count
eval_set.test_cases.destroy_all
puts "🗑️  Cleared #{old_count} existing test cases"

# Step 4: Load patent test cases from transformed ground truth CSV
ground_truth_file = Rails.root.join('groundt', 'gt_transformed_for_llm.csv')

unless File.exist?(ground_truth_file)
  puts "❌ Error: Transformed ground truth file not found at #{ground_truth_file}"
  puts "Run 'ruby scripts/transform_new_ground_truth.rb' first!"
  exit 1
end

test_cases_created = 0
errors = []

CSV.foreach(ground_truth_file, headers: true, encoding: 'UTF-8') do |row|
  begin
    patent_number = row['patent_number']
    claim_number = row['claim_number'].to_i
    claim_text = row['claim_text']
    abstract = row['abstract']

    # Ground truth expected output (JSON format with 3 fields)
    expected_output = {
      subject_matter: row['gt_subject_matter'],
      inventive_concept: row['gt_inventive_concept'],
      overall_eligibility: row['gt_overall_eligibility']
    }.to_json

    # Create test case with full patent data
    PromptEngine::TestCase.create!(
      eval_set: eval_set,
      input_variables: {
        patent_id: patent_number,
        claim_number: claim_number,
        claim_text: claim_text,
        abstract: abstract
      }.to_json,
      expected_output: expected_output,
      description: "#{patent_number} Claim #{claim_number}"
    )

    test_cases_created += 1

    if test_cases_created % 10 == 0
      puts "  Imported #{test_cases_created} test cases..."
    end

  rescue => e
    errors << "#{patent_number}: #{e.message}"
  end
end

puts "\n" + "=" * 80
puts "✅ Import Complete!"
puts "📝 Created: #{test_cases_created} test cases"
puts "📁 Prompt ID: #{prompt.id}"
puts "📁 Eval Set ID: #{eval_set.id}"

if errors.any?
  puts "\n⚠️  Errors (#{errors.length}):"
  errors.first(5).each { |err| puts "  - #{err}" }
end

puts "\n🎉 Ready to run evaluations!"
puts "Access at: /prompt_engine/prompts/#{prompt.id}/eval_sets/#{eval_set.id}?mode=run_form"
