#!/usr/bin/env ruby
# Verify ground truth data is correctly loaded and mapped

puts "Verifying Ground Truth Data"
puts "=" * 80

# Check 1: CSV file exists
csv_file = Rails.root.join('groundt', 'gt_transformed_for_llm.csv')
if File.exist?(csv_file)
  puts "✅ CSV file exists: #{csv_file}"
else
  puts "❌ CSV file NOT FOUND: #{csv_file}"
  exit 1
end

# Check 2: Load ground truth like controller does
require 'csv'

ground_truth_data = {}
CSV.foreach(csv_file, headers: true, encoding: 'UTF-8') do |row|
  key = "#{row['patent_number']}_#{row['claim_number']}"
  ground_truth_data[key] = {
    patent_number: row['patent_number'],
    claim_number: row['claim_number'].to_i,
    subject_matter: row['gt_subject_matter'],
    inventive_concept: row['gt_inventive_concept'],
    overall_eligibility: row['gt_overall_eligibility']
  }
end

puts "✅ Loaded #{ground_truth_data.length} patents from CSV"
puts ""

# Check 3: Verify test cases match ground truth
test_cases = PromptEngine::TestCase.all
puts "Found #{test_cases.count} test cases in database"
puts ""

# Check 4: Sample verification
puts "Verifying Sample Patents:"
puts "-" * 80

test_cases.first(5).each do |tc|
  input_vars = JSON.parse(tc.input_variables)
  patent_id = input_vars['patent_id']
  claim_number = input_vars['claim_number']
  key = "#{patent_id}_#{claim_number}"

  gt = ground_truth_data[key]

  if gt
    expected = JSON.parse(tc.expected_output)

    # Verify expected output matches ground truth
    sm_match = expected['subject_matter'] == gt[:subject_matter]
    ic_match = expected['inventive_concept'] == gt[:inventive_concept]
    oe_match = expected['overall_eligibility'] == gt[:overall_eligibility]

    all_match = sm_match && ic_match && oe_match

    status = all_match ? "✅" : "❌"
    puts "#{status} #{patent_id} (Claim #{claim_number})"
    puts "   Expected in DB: #{expected.inspect}"
    puts "   Ground Truth:   #{gt.slice(:subject_matter, :inventive_concept, :overall_eligibility).inspect}"

    unless all_match
      puts "   ⚠️  MISMATCH!"
      puts "      SM: #{sm_match ? '✓' : '✗ ' + expected['subject_matter'].to_s + ' != ' + gt[:subject_matter].to_s}"
      puts "      IC: #{ic_match ? '✓' : '✗ ' + expected['inventive_concept'].to_s + ' != ' + gt[:inventive_concept].to_s}"
      puts "      OE: #{oe_match ? '✓' : '✗ ' + expected['overall_eligibility'].to_s + ' != ' + gt[:overall_eligibility].to_s}"
    end
    puts ""
  else
    puts "❌ #{patent_id} - NOT FOUND in ground truth CSV!"
    puts ""
  end
end

# Check 5: Verify specific known patents
puts "Checking Known Patents:"
puts "-" * 80

known_patents = {
  "US6128415A_1" => {
    subject_matter: "Abstract",
    inventive_concept: "No",
    overall_eligibility: "Ineligible"
  },
  "US7644019B2_1" => {
    subject_matter: "Abstract",
    inventive_concept: "No",
    overall_eligibility: "Ineligible"
  }
}

known_patents.each do |key, expected_gt|
  gt = ground_truth_data[key]

  if gt
    match = gt[:subject_matter] == expected_gt[:subject_matter] &&
            gt[:inventive_concept] == expected_gt[:inventive_concept] &&
            gt[:overall_eligibility] == expected_gt[:overall_eligibility]

    status = match ? "✅" : "❌"
    puts "#{status} #{key}: #{match ? 'Correct' : 'WRONG'}"

    unless match
      puts "   Expected: #{expected_gt.inspect}"
      puts "   Got:      #{gt.slice(:subject_matter, :inventive_concept, :overall_eligibility).inspect}"
    end
  else
    puts "❌ #{key}: NOT FOUND"
  end
end

puts ""
puts "=" * 80
puts "Verification Complete"
