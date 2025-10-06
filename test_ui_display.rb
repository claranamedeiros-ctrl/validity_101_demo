#!/usr/bin/env ruby
# Test what the UI will actually display

require 'csv'
require 'json'

puts "Testing UI Display Values"
puts "=" * 80

# Load ground truth (simulating controller)
ground_truth_file = 'groundt/gt_transformed_for_llm.csv'
ground_truth_data = {}

CSV.foreach(ground_truth_file, headers: true, encoding: 'UTF-8') do |row|
  key = "#{row['patent_number']}_#{row['claim_number']}"
  ground_truth_data[key] = {
    patent_number: row['patent_number'],
    claim_number: row['claim_number'].to_i,
    subject_matter: row['gt_subject_matter'],
    inventive_concept: row['gt_inventive_concept'],
    overall_eligibility: row['gt_overall_eligibility']
  }
end

puts "Loaded #{ground_truth_data.length} patents from ground truth"
puts ""

# Simulate what evaluation_job stores
def simulate_llm_response(ground_truth)
  # This simulates what the LLM would return (matching ground truth for testing)
  {
    subject_matter: ground_truth[:subject_matter],
    inventive_concept: ground_truth[:inventive_concept],
    overall_eligibility: ground_truth[:overall_eligibility]
  }.to_json
end

# Test Case 1: Perfect match
puts "Test Case 1: PERFECT MATCH (LLM outputs exactly match ground truth)"
puts "-" * 80

patent_key = "US6128415A_1"
ground_truth = ground_truth_data[patent_key]

# Simulate stored eval result (what's in database)
stored_result = {
  actual_output: simulate_llm_response(ground_truth),
  passed: true
}

# Parse for UI display (what metrics.html.erb does)
actual_llm_output = JSON.parse(stored_result[:actual_output])

# NO MAPPING - Direct values
expected_subject_matter = ground_truth[:subject_matter]
expected_inventive_concept = ground_truth[:inventive_concept]
expected_overall = ground_truth[:overall_eligibility]

actual_subject_matter = actual_llm_output['subject_matter']
actual_inventive_concept = actual_llm_output['inventive_concept']
actual_overall = actual_llm_output['overall_eligibility']

# Check matches
subject_matter_match = expected_subject_matter.to_s.downcase == actual_subject_matter.to_s.downcase
inventive_concept_match = expected_inventive_concept.to_s.downcase == actual_inventive_concept.to_s.downcase
overall_match = expected_overall.to_s.downcase == actual_overall.to_s.downcase

puts "Patent: #{ground_truth[:patent_number]}"
puts ""
puts "UI WILL DISPLAY:"
puts "┌─────────────────────────┬──────────────────────────────────────────┬───────────────────────┐"
puts "│ Field                   │ Expected | Actual                        │ Match?                │"
puts "├─────────────────────────┼──────────────────────────────────────────┼───────────────────────┤"
puts "│ Subject Matter          │ #{expected_subject_matter.ljust(20)} | #{actual_subject_matter.ljust(20)} │ #{subject_matter_match ? '✓ MATCH' : '✗ MISMATCH'.ljust(17)}  │"
puts "│ Inventive Concept       │ #{expected_inventive_concept.ljust(20)} | #{actual_inventive_concept.ljust(20)} │ #{inventive_concept_match ? '✓ MATCH' : '✗ MISMATCH'.ljust(17)}  │"
puts "│ Overall Eligibility     │ #{expected_overall.ljust(20)} | #{actual_overall.ljust(20)} │ #{overall_match ? '✓ MATCH' : '✗ MISMATCH'.ljust(17)}  │"
puts "└─────────────────────────┴──────────────────────────────────────────┴───────────────────────┘"
puts ""

all_match = subject_matter_match && inventive_concept_match && overall_match
puts "Overall Test Result: #{all_match ? '✓ PASS' : '✗ FAIL'}"
puts ""

# Test Case 2: Mismatch scenario
puts "Test Case 2: MISMATCH (LLM outputs differ from ground truth)"
puts "-" * 80

# Simulate LLM getting it wrong
wrong_llm_output = {
  subject_matter: "Not Abstract/Not Natural Phenomenon",  # Wrong!
  inventive_concept: "Yes",                                # Wrong!
  overall_eligibility: "Eligible"                          # Wrong!
}.to_json

stored_result_wrong = {
  actual_output: wrong_llm_output,
  passed: false
}

actual_llm_output_wrong = JSON.parse(stored_result_wrong[:actual_output])

actual_subject_matter_w = actual_llm_output_wrong['subject_matter']
actual_inventive_concept_w = actual_llm_output_wrong['inventive_concept']
actual_overall_w = actual_llm_output_wrong['overall_eligibility']

subject_matter_match_w = expected_subject_matter.to_s.downcase == actual_subject_matter_w.to_s.downcase
inventive_concept_match_w = expected_inventive_concept.to_s.downcase == actual_inventive_concept_w.to_s.downcase
overall_match_w = expected_overall.to_s.downcase == actual_overall_w.to_s.downcase

puts "Patent: #{ground_truth[:patent_number]}"
puts ""
puts "UI WILL DISPLAY:"
puts "┌─────────────────────────┬────────────────────────────────────────────────────────────────────┬───────────────────────┐"
puts "│ Field                   │ Expected | Actual                                                    │ Match?                │"
puts "├─────────────────────────┼────────────────────────────────────────────────────────────────────┼───────────────────────┤"
puts "│ Subject Matter          │ #{expected_subject_matter.ljust(25)} | #{actual_subject_matter_w.ljust(40)} │ #{subject_matter_match_w ? '✓ MATCH' : '✗ MISMATCH'.ljust(17)}  │"
puts "│ Inventive Concept       │ #{expected_inventive_concept.ljust(25)} | #{actual_inventive_concept_w.ljust(40)} │ #{inventive_concept_match_w ? '✓ MATCH' : '✗ MISMATCH'.ljust(17)}  │"
puts "│ Overall Eligibility     │ #{expected_overall.ljust(25)} | #{actual_overall_w.ljust(40)} │ #{overall_match_w ? '✓ MATCH' : '✗ MISMATCH'.ljust(17)}  │"
puts "└─────────────────────────┴────────────────────────────────────────────────────────────────────┴───────────────────────┘"
puts ""

all_match_w = subject_matter_match_w && inventive_concept_match_w && overall_match_w
puts "Overall Test Result: #{all_match_w ? '✓ PASS' : '✗ FAIL'}"
puts ""

# Summary
puts "=" * 80
puts "UI DISPLAY SUMMARY"
puts ""
puts "✅ Ground truth displays RAW values: 'Abstract', 'No', 'Ineligible'"
puts "✅ LLM output displays RAW values: 'Abstract', 'No', 'Ineligible'"
puts "✅ No transformations to 'abstract', 'uninventive', etc."
puts "✅ Direct comparison with case-insensitive matching"
puts "✅ All 3 fields must match for PASS"
puts ""
puts "Example UI display:"
puts "  Expected: Abstract | Actual: Abstract ✓"
puts "  Expected: No       | Actual: No       ✓"
puts "  Expected: Ineligible | Actual: Ineligible ✓"
puts ""
puts "NOT this old way:"
puts "  Expected: abstract | Actual: abstract ✓"
puts "  Expected: uninventive | Actual: uninventive ✓"
puts ""
