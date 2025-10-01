# Production Data Import Script
# Run with: rails runner scripts/import_production_data.rb

puts "🚀 Starting production data import..."

# Step 1: Create or find the Validity Analysis prompt
prompt = PromptEngine::Prompt.find_or_create_by!(name: "validity-101-agent") do |p|
  p.description = "AI-powered patent validity analysis using Alice Test methodology"

  # Load system prompt from backend/system.erb
  system_prompt_path = Rails.root.join('backend', 'system.erb')
  if File.exist?(system_prompt_path)
    p.system_message = File.read(system_prompt_path)
    puts "✅ Loaded system prompt from backend/system.erb"
  else
    puts "⚠️  Warning: backend/system.erb not found, using default"
    p.system_message = "You are a patent validity analysis expert."
  end

  # Load user prompt template from backend/user.erb
  user_prompt_path = Rails.root.join('backend', 'user.erb')
  if File.exist?(user_prompt_path)
    p.content = File.read(user_prompt_path)
    puts "✅ Loaded user prompt from backend/user.erb"
  else
    puts "⚠️  Warning: backend/user.erb not found, using default"
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
  p.status = "active"  # CRITICAL: Must be 'active' for PromptEngine.render to find it
end

puts "✅ Created/Updated Prompt: #{prompt.name} (ID: #{prompt.id})"

# Step 2: Skip prompt version (PromptEngine may not have this association)
puts "⏭️  Skipping prompt version creation (not needed for evaluation)"

# Step 3: Create evaluation set
eval_set = PromptEngine::EvalSet.find_or_create_by!(prompt: prompt, name: "Patent Validity Test Cases") do |es|
  es.description = "Test cases for patent validity analysis covering 50 patents from ground truth CSV"
  es.grader_type = "exact_match" # CRITICAL: Use exact_match, not contains!
end

puts "✅ Created/Updated Eval Set: #{eval_set.name} (ID: #{eval_set.id})"

# Step 4: Load patent test cases from ground truth CSV
ground_truth_file = Rails.root.join('groundt', 'gt_aligned_normalized_test.csv')

unless File.exist?(ground_truth_file)
  puts "❌ Error: Ground truth file not found at #{ground_truth_file}"
  exit 1
end

require 'csv'

# Clear existing test cases to avoid duplicates
eval_set.test_cases.destroy_all
puts "🗑️  Cleared existing test cases"

test_cases_created = 0

CSV.foreach(ground_truth_file, headers: true) do |row|
  patent_number = row['patent_number']
  claim_number = row['claim_number']

  # Map ground truth to expected LLM output format (for grading)
  gt_subject_matter = row['gt_subject_matter']
  gt_inventive_concept = row['gt_inventive_concept']
  gt_eligibility = row['gt_overall_eligibility']

  # Transform ground truth to match what we're grading against (overall_eligibility)
  # We grade on overall_eligibility field only
  expected_output = gt_eligibility

  # Create test case with patent data
  PromptEngine::TestCase.create!(
    eval_set: eval_set,
    input_variables: {
      patent_id: patent_number,
      claim_number: claim_number.to_i,
      claim_text: "Claim text for #{patent_number}", # Placeholder - add real data if available
      abstract: "Abstract for #{patent_number}" # Placeholder - add real data if available
    }.to_json,
    expected_output: expected_output,
    description: "#{patent_number} Claim #{claim_number}"
  )

  test_cases_created += 1
end

puts "✅ Created #{test_cases_created} patent validity test cases"

puts ""
puts "🎉 Production data import completed successfully!"
puts ""
puts "📊 Summary:"
puts "  - Prompt ID: #{prompt.id} (#{prompt.name})"
puts "  - Eval Set ID: #{eval_set.id} (#{eval_set.name})"
puts "  - Test Cases: #{test_cases_created}"
puts ""
puts "🔗 Access your evaluation at:"
puts "  https://your-railway-url.railway.app/prompt_engine/prompts/#{prompt.id}/eval_sets/#{eval_set.id}"
