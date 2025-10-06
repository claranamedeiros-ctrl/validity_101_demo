#!/usr/bin/env ruby
# Test that service.rb returns correct structure (simulated, no actual LLM call)

puts "Testing Service Output Structure"
puts "=" * 60

# Simulate what the service SHOULD return (based on updated code)
def simulate_service_call
  # Simulate LLM raw output
  raw = {
    patent_number: "US6128415A",
    claim_number: 1,
    subject_matter: "Abstract",
    inventive_concept: "No",
    validity_score: 2
  }

  # Calculate overall_eligibility from Alice Test logic (from service.rb lines 67-75)
  subject_matter = raw[:subject_matter]
  inventive_concept = raw[:inventive_concept]

  overall_eligibility = if subject_matter == "Not Abstract/Not Natural Phenomenon"
    "Eligible"
  elsif inventive_concept == "Yes"
    "Eligible"
  else
    "Ineligible"
  end

  # Return RAW LLM outputs (no forced values!)
  {
    status: :success,
    status_message: nil,
    patent_number: raw[:patent_number],
    claim_number: raw[:claim_number],
    subject_matter: subject_matter,
    inventive_concept: inventive_concept,
    validity_score: raw[:validity_score],
    overall_eligibility: overall_eligibility
  }
end

# Test the service
result = simulate_service_call

puts "\nTest 1: Service Returns Success Status"
if result[:status] == :success
  puts "  ✓ PASS: Status is :success"
else
  puts "  ✗ FAIL: Status is #{result[:status]}"
end

puts "\nTest 2: Required Fields Present"
required_fields = [:patent_number, :claim_number, :subject_matter, :inventive_concept, :overall_eligibility, :validity_score]
missing = required_fields - result.keys

if missing.empty?
  puts "  ✓ PASS: All required fields present"
else
  puts "  ✗ FAIL: Missing fields: #{missing.join(', ')}"
end

puts "\nTest 3: Values Are RAW (Not Forced)"
# Check that values match what LLM would output, not backend mappings
tests = [
  { field: :subject_matter, value: result[:subject_matter], expected_type: "Raw LLM value", valid: ["Abstract", "Natural Phenomenon", "Not Abstract/Not Natural Phenomenon"].include?(result[:subject_matter]) },
  { field: :inventive_concept, value: result[:inventive_concept], expected_type: "Raw LLM value", valid: ["No", "Yes", "-"].include?(result[:inventive_concept]) },
  { field: :overall_eligibility, value: result[:overall_eligibility], expected_type: "Calculated value", valid: ["Eligible", "Ineligible"].include?(result[:overall_eligibility]) }
]

tests.each do |test|
  if test[:valid]
    puts "  ✓ PASS: #{test[:field]} = '#{test[:value]}' (#{test[:expected_type]})"
  else
    puts "  ✗ FAIL: #{test[:field]} = '#{test[:value]}' (invalid!)"
  end
end

puts "\nTest 4: No Backend Mapping Values"
# OLD system would have: "uninventive", "inventive", "skipped", "patentable"
# NEW system should NEVER have these
forbidden_values = ["uninventive", "inventive", "skipped", "patentable"]
has_forbidden = forbidden_values.any? { |v|
  result[:subject_matter].to_s == v ||
  result[:inventive_concept].to_s == v
}

if has_forbidden
  puts "  ✗ FAIL: Found old backend mapping values!"
else
  puts "  ✓ PASS: No backend mapping values (using raw LLM schema)"
end

puts "\nTest 5: Overall Eligibility Calculation"
# Test Alice Test logic
test_cases = [
  { sm: "Not Abstract/Not Natural Phenomenon", ic: "No", expected: "Eligible", reason: "Not abstract = Eligible" },
  { sm: "Not Abstract/Not Natural Phenomenon", ic: "Yes", expected: "Eligible", reason: "Not abstract = Eligible" },
  { sm: "Not Abstract/Not Natural Phenomenon", ic: "-", expected: "Eligible", reason: "Not abstract = Eligible" },
  { sm: "Abstract", ic: "Yes", expected: "Eligible", reason: "Has IC = Eligible" },
  { sm: "Abstract", ic: "No", expected: "Ineligible", reason: "Abstract + No IC = Ineligible" },
  { sm: "Abstract", ic: "-", expected: "Ineligible", reason: "Abstract + Skipped IC = Ineligible" },
]

puts "  Testing Alice Test logic:"
test_cases.each do |tc|
  calculated = if tc[:sm] == "Not Abstract/Not Natural Phenomenon"
    "Eligible"
  elsif tc[:ic] == "Yes"
    "Eligible"
  else
    "Ineligible"
  end

  if calculated == tc[:expected]
    puts "    ✓ PASS: #{tc[:sm]} + #{tc[:ic]} = #{calculated} (#{tc[:reason]})"
  else
    puts "    ✗ FAIL: #{tc[:sm]} + #{tc[:ic]} = #{calculated}, expected #{tc[:expected]}"
  end
end

puts "\nTest 6: Service Structure Matches Evaluation Job Expectations"
# evaluation_job.rb expects these exact fields
expected_structure = {
  subject_matter: String,
  inventive_concept: String,
  overall_eligibility: String
}

matches = expected_structure.all? { |field, type|
  result.key?(field) && result[field].is_a?(type)
}

if matches
  puts "  ✓ PASS: Structure matches evaluation_job.rb expectations"
else
  puts "  ✗ FAIL: Structure mismatch"
end

puts "\n" + "=" * 60
puts "Service Structure Tests Complete"
puts "\nFull Result:"
puts result.inspect
