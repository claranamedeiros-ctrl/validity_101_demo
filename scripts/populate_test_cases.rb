#!/usr/bin/env ruby
require 'csv'

puts "Creating Prompt and EvalSet..."

prompt = PromptEngine::Prompt.find_or_create_by(id: 1) do |p|
  p.name = 'Patent Validity Analysis'
  p.description = 'AI-powered patent validity analysis'
end
puts "Prompt: #{prompt.name} (ID: #{prompt.id})"

eval_set = PromptEngine::EvalSet.find_or_create_by(id: 2) do |es|
  es.prompt = prompt
  es.name = 'Patent Validity Test Cases'
  es.description = 'Test cases for 50 patents'
end
puts "Eval Set: #{eval_set.name} (ID: #{eval_set.id})"

csv_path = Rails.root.join('groundt', 'gt_aligned_normalized_test.csv')
puts "Loading from #{csv_path}"

count = 0
CSV.foreach(csv_path, headers: true) do |row|
  next if row['patent_number'].nil?

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

puts "✅ Created #{count} test cases"
puts "Total test cases in eval set: #{eval_set.test_cases.count}"
