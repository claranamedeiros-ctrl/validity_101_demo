require 'csv'

csv = CSV.read("groundt/gt_transformed_for_llm.csv", headers: true, encoding: "UTF-8")
puts "Total patents: #{csv.length}"
puts "Expected: 50"
puts csv.length == 50 ? "PASS: Correct count" : "FAIL: Wrong count"
puts ""

# Check required columns
required = ["patent_number", "claim_number", "claim_text", "abstract", "gt_subject_matter", "gt_inventive_concept", "gt_overall_eligibility"]
missing = required - csv.headers
if missing.empty?
  puts "PASS: All required columns present"
else
  puts "FAIL: Missing columns: #{missing.join(", ")}"
end
puts ""

# Check for valid enum values
valid_sm = ["Abstract", "Natural Phenomenon", "Not Abstract/Not Natural Phenomenon"]
valid_ic = ["No", "Yes", "-"]
valid_oe = ["Eligible", "Ineligible"]

invalid_sm = []
invalid_ic = []
invalid_oe = []

csv.each do |row|
  invalid_sm << row["patent_number"] unless valid_sm.include?(row["gt_subject_matter"])
  invalid_ic << row["patent_number"] unless valid_ic.include?(row["gt_inventive_concept"])
  invalid_oe << row["patent_number"] unless valid_oe.include?(row["gt_overall_eligibility"])
end

puts "Checking enum values..."
puts invalid_sm.empty? ? "PASS: All subject_matter values valid" : "FAIL: Invalid subject_matter in: #{invalid_sm.join(', ')}"
puts invalid_ic.empty? ? "PASS: All inventive_concept values valid" : "FAIL: Invalid inventive_concept in: #{invalid_ic.join(', ')}"
puts invalid_oe.empty? ? "PASS: All overall_eligibility values valid" : "FAIL: Invalid overall_eligibility in: #{invalid_oe.join(', ')}"
puts ""

# Check for empty claim text or abstract
empty_claims = []
empty_abstracts = []

csv.each do |row|
  empty_claims << row["patent_number"] if row["claim_text"].to_s.strip.empty?
  empty_abstracts << row["patent_number"] if row["abstract"].to_s.strip.empty?
end

puts "Checking content..."
puts empty_claims.empty? ? "PASS: All patents have claim text" : "FAIL: #{empty_claims.length} patents missing claim text: #{empty_claims.join(', ')}"
puts empty_abstracts.empty? ? "PASS: All patents have abstracts" : "FAIL: #{empty_abstracts.length} patents missing abstracts: #{empty_abstracts.join(', ')}"

puts ""
puts "Sample patent (first row):"
first = csv.first
puts "  Patent: #{first['patent_number']}"
puts "  Claim text: #{first['claim_text'][0..100]}..."
puts "  Abstract: #{first['abstract'][0..100]}..."
puts "  Subject Matter: #{first['gt_subject_matter']}"
puts "  Inventive Concept: #{first['gt_inventive_concept']}"
puts "  Overall Eligibility: #{first['gt_overall_eligibility']}"
