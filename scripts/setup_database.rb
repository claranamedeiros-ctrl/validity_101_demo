#!/usr/bin/env ruby
require 'csv'

puts "=" * 80
puts "SETTING UP DATABASE FOR VALIDITY 101"
puts "=" * 80

# Step 1: Create the prompt with the full prompt from full_prompt.md
puts "\n1. Creating Prompt..."

prompt_content = File.read(Rails.root.join('full_prompt.md'))

prompt = PromptEngine::Prompt.find_or_create_by(id: 1) do |p|
  p.name = 'Patent Validity Analysis - Alice Test'
  p.description = '101 Validity Agent using Alice Test methodology'
  p.status = 'active'
end

# Create or update the prompt version
if prompt.prompt_versions.empty?
  prompt.prompt_versions.create!(
    content: prompt_content,
    system_message: "You are a judge at the U.S. Court of Appeals for the Federal Circuit.",
    version_number: 1
  )
  puts "   ✅ Created prompt version"
else
  puts "   ⏭️  Prompt version already exists"
end

puts "   Prompt ID: #{prompt.id}, Name: #{prompt.name}"

# Step 2: Create the eval set
puts "\n2. Creating Evaluation Set..."

eval_set = PromptEngine::EvalSet.find_or_create_by(id: 2) do |es|
  es.prompt = prompt
  es.name = 'Patent Validity Test Cases - 50 Patents'
  es.description = 'Ground truth data from gt_transformed_for_llm.csv'
end

puts "   Eval Set ID: #{eval_set.id}, Name: #{eval_set.name}"

# Step 3: Load test cases from CSV
puts "\n3. Loading Test Cases from CSV..."

csv_path = Rails.root.join('groundt', 'gt_transformed_for_llm.csv')

unless File.exist?(csv_path)
  puts "   ❌ CSV file not found at #{csv_path}"
  exit 1
end

existing_count = eval_set.test_cases.count
if existing_count > 0
  puts "   ⏭️  #{existing_count} test cases already exist, skipping import"
else
  count = 0
  CSV.foreach(csv_path, headers: true) do |row|
    next if row['patent_number'].nil? || row['patent_number'].strip.empty?

    PromptEngine::TestCase.create!(
      eval_set: eval_set,
      description: "Patent #{row['patent_number']} Claim #{row['claim_number']}",
      input_variables: {
        patent_id: row['patent_number'],
        claim_number: row['claim_number'],
        claim_text: row['claim_text'],
        abstract: row['abstract']
      }.to_json,
      expected_output: {
        subject_matter: row['gt_subject_matter'],
        inventive_concept: row['gt_inventive_concept'],
        overall_eligibility: row['gt_overall_eligibility']
      }.to_json
    )
    count += 1
  end

  puts "   ✅ Created #{count} test cases"
end

# Step 4: Summary
puts "\n" + "=" * 80
puts "SETUP COMPLETE"
puts "=" * 80
puts "Prompt ID: #{prompt.id}"
puts "Eval Set ID: #{eval_set.id}"
puts "Test Cases: #{eval_set.test_cases.count}"
puts "\nAccess at:"
puts "https://validity101demo-production.up.railway.app/prompt_engine/prompts/#{prompt.id}/eval_sets/#{eval_set.id}"
puts "=" * 80
