#!/usr/bin/env ruby
# Test controller CSV loading logic

require 'csv'

puts "Testing Controller CSV Loading"
puts "=" * 60

# Simulate the controller's load_ground_truth_data method
def load_ground_truth_data
  ground_truth_file = 'groundt/gt_transformed_for_llm.csv'
  return {} unless File.exist?(ground_truth_file)

  ground_truth = {}
  CSV.foreach(ground_truth_file, headers: true, encoding: 'UTF-8') do |row|
    key = "#{row['patent_number']}_#{row['claim_number']}"

    # NO mapping needed - values already match LLM schema exactly!
    ground_truth[key] = {
      patent_number: row['patent_number'],
      claim_number: row['claim_number'].to_i,
      claim_text: row['claim_text'],
      abstract: row['abstract'],
      subject_matter: row['gt_subject_matter'],
      inventive_concept: row['gt_inventive_concept'],
      overall_eligibility: row['gt_overall_eligibility']
    }
  end
  ground_truth
rescue => e
  puts "ERROR: Failed to load ground truth data: #{e.message}"
  {}
end

# Test loading
ground_truth = load_ground_truth_data

puts "\nTest 1: CSV File Loading"
if ground_truth.empty?
  puts "  ✗ FAIL: No data loaded"
  exit 1
else
  puts "  ✓ PASS: Loaded #{ground_truth.length} patents"
end

puts "\nTest 2: Check Sample Patent (US6128415A_1)"
key = "US6128415A_1"
if ground_truth[key]
  puts "  ✓ PASS: Found patent US6128415A"
  patent = ground_truth[key]
  puts "    Patent Number: #{patent[:patent_number]}"
  puts "    Claim Number: #{patent[:claim_number]}"
  puts "    Has Claim Text: #{!patent[:claim_text].to_s.empty?}"
  puts "    Has Abstract: #{!patent[:abstract].to_s.empty?}"
  puts "    Subject Matter: #{patent[:subject_matter]}"
  puts "    Inventive Concept: #{patent[:inventive_concept]}"
  puts "    Overall Eligibility: #{patent[:overall_eligibility]}"
else
  puts "  ✗ FAIL: Patent US6128415A_1 not found"
end

puts "\nTest 3: Verify Values Match LLM Schema"
patent = ground_truth["US6128415A_1"]
valid_sm = ["Abstract", "Natural Phenomenon", "Not Abstract/Not Natural Phenomenon"]
valid_ic = ["No", "Yes", "-"]
valid_oe = ["Eligible", "Ineligible"]

tests = [
  {
    name: "Subject Matter",
    value: patent[:subject_matter],
    valid: valid_sm.include?(patent[:subject_matter])
  },
  {
    name: "Inventive Concept",
    value: patent[:inventive_concept],
    valid: valid_ic.include?(patent[:inventive_concept])
  },
  {
    name: "Overall Eligibility",
    value: patent[:overall_eligibility],
    valid: valid_oe.include?(patent[:overall_eligibility])
  }
]

tests.each do |test|
  if test[:valid]
    puts "  ✓ PASS: #{test[:name]} = '#{test[:value]}' (valid)"
  else
    puts "  ✗ FAIL: #{test[:name]} = '#{test[:value]}' (INVALID!)"
  end
end

puts "\nTest 4: Check All 50 Patents Load Correctly"
expected_count = 50
if ground_truth.length == expected_count
  puts "  ✓ PASS: All #{expected_count} patents loaded"
else
  puts "  ✗ FAIL: Expected #{expected_count}, got #{ground_truth.length}"
end

puts "\nTest 5: Verify No Value Mapping Happened"
# The old system would map "no ic found" → "uninventive"
# The new system should keep "No" as "No"
sample_patents = ground_truth.values.first(5)
has_old_values = sample_patents.any? { |p|
  p[:inventive_concept] == "uninventive" ||
  p[:inventive_concept] == "inventive" ||
  p[:subject_matter] == "patentable"
}

if has_old_values
  puts "  ✗ FAIL: Found old mapped values (uninventive/inventive/patentable)"
else
  puts "  ✓ PASS: No old mapped values found (using raw schema values)"
end

puts "\n" + "=" * 60
puts "Controller CSV Loading Tests Complete"
