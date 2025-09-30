#!/usr/bin/env ruby

require 'csv'

# Script to convert Ground_truthg.csv to the proper format for our system
# Input: Ground_truthg.csv with columns: Patent Number,Claim Text,Abstract,Alice Step One,Alice Step Two,Overall Eligibility
# Output: New ground truth CSV with the correct backend enum values

# Transformation mappings to controller-expected format
ALICE_STEP_ONE_MAPPING = {
  'Abstract' => 'abstract',
  'Natural Phenomenon' => 'natural phenomenon',
  'Not Abstract' => 'not abstract'
}.freeze

ALICE_STEP_TWO_MAPPING = {
  'No IC Found' => 'no ic found',
  'IC Found' => 'ic found',
  'N/A' => 'skipped'
}.freeze

OVERALL_ELIGIBILITY_MAPPING = {
  'Eligible' => 'eligible',
  'Ineligible' => 'ineligible'
}.freeze

input_file = '/Users/anaclaramedeiros/Documents/validity_101_demo/Ground_truthg.csv'
output_file = '/Users/anaclaramedeiros/Documents/validity_101_demo/groundt/gt_aligned_normalized_corrected.csv'

puts "Converting #{input_file} to #{output_file}..."

CSV.open(output_file, 'w') do |output_csv|
  # Write header for backend controller format: patent_number,claim_number,gt_subject_matter,gt_inventive_concept,gt_overall_eligibility
  output_csv << ['patent_number', 'claim_number', 'gt_subject_matter', 'gt_inventive_concept', 'gt_overall_eligibility']

  CSV.foreach(input_file, headers: true) do |row|
    patent_number = row['Patent Number']
    alice_step_one = row['Alice Step One']
    alice_step_two = row['Alice Step Two']
    overall_eligibility = row['Overall Eligibility']

    # Transform values using our mappings
    subject_matter = ALICE_STEP_ONE_MAPPING[alice_step_one] || alice_step_one
    inventive_concept = ALICE_STEP_TWO_MAPPING[alice_step_two] || alice_step_two
    eligibility = OVERALL_ELIGIBILITY_MAPPING[overall_eligibility] || overall_eligibility

    # Our system uses claim_number = 1 for all entries
    output_csv << [patent_number, 1, subject_matter, inventive_concept, eligibility]

    puts "Converted #{patent_number}: #{alice_step_one} -> #{subject_matter}, #{alice_step_two} -> #{inventive_concept}, #{overall_eligibility} -> #{eligibility}"
  end
end

puts "Conversion complete! Output file: #{output_file}"
puts ""
puts "Summary of transformations applied:"
puts "Alice Step One mappings:"
ALICE_STEP_ONE_MAPPING.each { |k,v| puts "  '#{k}' -> '#{v}'" }
puts "Alice Step Two mappings:"
ALICE_STEP_TWO_MAPPING.each { |k,v| puts "  '#{k}' -> '#{v}'" }
puts "Overall Eligibility mappings:"
OVERALL_ELIGIBILITY_MAPPING.each { |k,v| puts "  '#{k}' -> '#{v}'" }