# Import Full Patent Data with Real Claim Text and Abstracts
# Run with: rails runner scripts/import_full_patent_data.rb

require 'csv'

puts "🚀 Importing full patent data from Ground_truthg.csv..."

# Step 1: Create or update the prompt
prompt = PromptEngine::Prompt.find_or_create_by!(name: "validity-101-agent") do |p|
  p.description = "AI-powered patent validity analysis using Alice Test methodology"

  system_prompt_path = Rails.root.join('backend', 'system.erb')
  if File.exist?(system_prompt_path)
    p.system_message = File.read(system_prompt_path)
    puts "✅ Loaded system prompt from backend/system.erb"
  else
    p.system_message = "You are a patent validity analysis expert."
  end

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
end

# Always update status to active
prompt.update!(status: "active")
puts "✅ Prompt: #{prompt.name} (ID: #{prompt.id}) - Status: #{prompt.status}"

# Step 2: Create evaluation set
eval_set = PromptEngine::EvalSet.find_or_create_by!(prompt: prompt, name: "Patent Validity Test Cases") do |es|
  es.description = "Test cases with full claim text and abstracts from Ground_truthg.csv"
  es.grader_type = "exact_match"
end

puts "✅ Eval Set: #{eval_set.name} (ID: #{eval_set.id})"

# Step 3: Load full patent data from Ground_truthg.csv
ground_truth_file = Rails.root.join('Ground_truthg.csv')

unless File.exist?(ground_truth_file)
  puts "❌ Error: Ground_truthg.csv not found at #{ground_truth_file}"
  exit 1
end

# Transformation mappings (from Ground_truthg format to backend format)
ALICE_STEP_ONE_MAPPING = {
  'Abstract' => 'abstract',
  'Natural Phenomenon' => 'natural_phenomenon',
  'Not Abstract' => 'not abstract'
}.freeze

ALICE_STEP_TWO_MAPPING = {
  'No IC Found' => 'no ic found',
  'IC Found' => 'ic found',
  'N/A' => 'skipped',
  '-' => 'skipped'
}.freeze

OVERALL_ELIGIBILITY_MAPPING = {
  'Eligible' => 'eligible',
  'Ineligible' => 'ineligible'
}.freeze

# Clear existing test cases
eval_set.test_cases.destroy_all
puts "🗑️  Cleared existing test cases"

test_cases_created = 0

CSV.foreach(ground_truth_file, headers: true) do |row|
  patent_number = row['Patent Number']
  claim_text = row['Claim Text']
  abstract = row['Abstract']
  alice_step_one = row['Alice Step One']
  alice_step_two = row['Alice Step Two']
  overall_eligibility = row['Overall Eligibility']

  # Skip if missing required data
  next if patent_number.nil? || claim_text.nil? || abstract.nil?

  # Transform ground truth values to backend format
  subject_matter = ALICE_STEP_ONE_MAPPING[alice_step_one] || alice_step_one&.downcase
  inventive_concept = ALICE_STEP_TWO_MAPPING[alice_step_two] || alice_step_two&.downcase
  eligibility = OVERALL_ELIGIBILITY_MAPPING[overall_eligibility] || overall_eligibility&.downcase

  # Create test case with FULL patent data
  PromptEngine::TestCase.create!(
    eval_set: eval_set,
    input_variables: {
      patent_id: patent_number,
      claim_number: 1,
      claim_text: claim_text,
      abstract: abstract
    }.to_json,
    expected_output: eligibility,
    description: "#{patent_number} Claim 1"
  )

  test_cases_created += 1
end

puts "✅ Created #{test_cases_created} test cases with FULL claim text and abstracts"
puts ""
puts "🎉 Import completed successfully!"
puts ""
puts "📊 Summary:"
puts "  - Prompt ID: #{prompt.id} (#{prompt.name})"
puts "  - Eval Set ID: #{eval_set.id} (#{eval_set.name})"
puts "  - Test Cases: #{test_cases_created}"
puts ""
puts "🔗 Run evaluation at:"
puts "  http://localhost:3000/prompt_engine/prompts/#{prompt.id}/eval_sets/#{eval_set.id}"
