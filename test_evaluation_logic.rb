#!/usr/bin/env ruby
# Test the evaluation comparison logic

puts "Testing Evaluation Comparison Logic"
puts "=" * 60

# Simulate the comparison logic from evaluation_job.rb
def grade_result(actual_output, expected_output)
  actual_subject_matter = actual_output[:subject_matter].to_s.strip.downcase
  expected_subject_matter = expected_output[:subject_matter].to_s.strip.downcase

  actual_inventive_concept = actual_output[:inventive_concept].to_s.strip.downcase
  expected_inventive_concept = expected_output[:inventive_concept].to_s.strip.downcase

  actual_eligibility = actual_output[:overall_eligibility].to_s.strip.downcase
  expected_eligibility = expected_output[:overall_eligibility].to_s.strip.downcase

  subject_matter_match = actual_subject_matter == expected_subject_matter
  inventive_concept_match = actual_inventive_concept == expected_inventive_concept
  eligibility_match = actual_eligibility == expected_eligibility

  passed = subject_matter_match && inventive_concept_match && eligibility_match

  {
    passed: passed,
    subject_matter_match: subject_matter_match,
    inventive_concept_match: inventive_concept_match,
    eligibility_match: eligibility_match
  }
end

# Test Case 1: Perfect match
puts "\nTest 1: Perfect Match"
actual = {
  subject_matter: "Abstract",
  inventive_concept: "No",
  overall_eligibility: "Ineligible"
}
expected = {
  subject_matter: "Abstract",
  inventive_concept: "No",
  overall_eligibility: "Ineligible"
}
result = grade_result(actual, expected)
puts "  Expected: PASS"
puts "  Got: #{result[:passed] ? 'PASS' : 'FAIL'}"
puts result[:passed] ? "  ✓ TEST PASSED" : "  ✗ TEST FAILED"

# Test Case 2: Subject matter mismatch
puts "\nTest 2: Subject Matter Mismatch"
actual = {
  subject_matter: "Abstract",
  inventive_concept: "No",
  overall_eligibility: "Ineligible"
}
expected = {
  subject_matter: "Not Abstract/Not Natural Phenomenon",
  inventive_concept: "No",
  overall_eligibility: "Ineligible"
}
result = grade_result(actual, expected)
puts "  Expected: FAIL"
puts "  Got: #{result[:passed] ? 'PASS' : 'FAIL'}"
puts !result[:passed] ? "  ✓ TEST PASSED (correctly failed)" : "  ✗ TEST FAILED (should have failed)"
puts "  Details: SM=#{result[:subject_matter_match]}, IC=#{result[:inventive_concept_match]}, OE=#{result[:eligibility_match]}"

# Test Case 3: Inventive concept mismatch
puts "\nTest 3: Inventive Concept Mismatch"
actual = {
  subject_matter: "Abstract",
  inventive_concept: "No",
  overall_eligibility: "Ineligible"
}
expected = {
  subject_matter: "Abstract",
  inventive_concept: "Yes",
  overall_eligibility: "Ineligible"
}
result = grade_result(actual, expected)
puts "  Expected: FAIL"
puts "  Got: #{result[:passed] ? 'PASS' : 'FAIL'}"
puts !result[:passed] ? "  ✓ TEST PASSED (correctly failed)" : "  ✗ TEST FAILED (should have failed)"

# Test Case 4: Overall eligibility mismatch
puts "\nTest 4: Overall Eligibility Mismatch"
actual = {
  subject_matter: "Abstract",
  inventive_concept: "No",
  overall_eligibility: "Ineligible"
}
expected = {
  subject_matter: "Abstract",
  inventive_concept: "No",
  overall_eligibility: "Eligible"
}
result = grade_result(actual, expected)
puts "  Expected: FAIL"
puts "  Got: #{result[:passed] ? 'PASS' : 'FAIL'}"
puts !result[:passed] ? "  ✓ TEST PASSED (correctly failed)" : "  ✗ TEST FAILED (should have failed)"

# Test Case 5: Case insensitive matching
puts "\nTest 5: Case Insensitive Matching"
actual = {
  subject_matter: "ABSTRACT",
  inventive_concept: "NO",
  overall_eligibility: "INELIGIBLE"
}
expected = {
  subject_matter: "abstract",
  inventive_concept: "no",
  overall_eligibility: "ineligible"
}
result = grade_result(actual, expected)
puts "  Expected: PASS (case insensitive)"
puts "  Got: #{result[:passed] ? 'PASS' : 'FAIL'}"
puts result[:passed] ? "  ✓ TEST PASSED" : "  ✗ TEST FAILED"

# Test Case 6: All three fields wrong
puts "\nTest 6: All Fields Wrong"
actual = {
  subject_matter: "Abstract",
  inventive_concept: "No",
  overall_eligibility: "Ineligible"
}
expected = {
  subject_matter: "Not Abstract/Not Natural Phenomenon",
  inventive_concept: "Yes",
  overall_eligibility: "Eligible"
}
result = grade_result(actual, expected)
puts "  Expected: FAIL"
puts "  Got: #{result[:passed] ? 'PASS' : 'FAIL'}"
puts !result[:passed] ? "  ✓ TEST PASSED (correctly failed)" : "  ✗ TEST FAILED (should have failed)"
puts "  Details: SM=#{result[:subject_matter_match]}, IC=#{result[:inventive_concept_match]}, OE=#{result[:eligibility_match]}"

puts "\n" + "=" * 60
puts "Evaluation Logic Tests Complete"
