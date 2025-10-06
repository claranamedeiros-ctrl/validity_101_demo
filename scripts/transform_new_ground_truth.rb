#!/usr/bin/env ruby
# Transforms the new Ground_truth.csv to match LLM schema format
# Input: groundt/Ground_truth.csv (with "Patent Number", "Claim #", etc.)
# Output: groundt/gt_transformed_for_llm.csv (with patent_number, claim_number, etc.)

require 'csv'
require 'fileutils'

# Transformation mappings to match LLM schema enums exactly
ALICE_STEP_ONE_MAPPING = {
  'Abstract' => 'Abstract',
  'Natural Phenomenon' => 'Natural Phenomenon',
  'Not Abstract' => 'Not Abstract/Not Natural Phenomenon'
}.freeze

ALICE_STEP_TWO_MAPPING = {
  'No IC Found' => 'No',
  'IC Found' => 'Yes',
  'N/A' => '-'
}.freeze

OVERALL_ELIGIBILITY_MAPPING = {
  'Eligible' => 'Eligible',
  'Ineligible' => 'Ineligible'
}.freeze

input_file = 'groundt/Ground_truth.csv'
output_file = 'groundt/gt_transformed_for_llm.csv'
backup_file = 'groundt/Ground_truth.csv.backup'

puts "🚀 Starting Ground Truth CSV Transformation"
puts "=" * 80

# Backup original file
if File.exist?(input_file)
  FileUtils.cp(input_file, backup_file)
  puts "✅ Backed up original CSV to #{backup_file}"
else
  puts "❌ Error: Input file not found: #{input_file}"
  exit 1
end

# Read and transform
begin
  csv_data = CSV.read(input_file, headers: true, encoding: 'UTF-8')
  puts "📊 Read #{csv_data.length} patent records"

  transformed_count = 0
  errors = []

  CSV.open(output_file, 'w', encoding: 'UTF-8') do |csv|
    # Write header with new column names
    csv << ['patent_number', 'claim_number', 'claim_text', 'abstract',
            'gt_subject_matter', 'gt_inventive_concept', 'gt_overall_eligibility']

    csv_data.each_with_index do |row, index|
      begin
        patent_number = row['Patent Number']
        claim_number = row['Claim #']
        claim_text = row['Claim Text']
        abstract = row['Abstract']
        alice_step_one = row['Alice Step One']
        alice_step_two = row['Alice Step Two']
        overall_eligibility = row['Overall Eligibility']

        # Validate required fields
        if patent_number.nil? || patent_number.strip.empty?
          errors << "Row #{index + 2}: Missing Patent Number"
          next
        end

        # Transform values to match LLM schema
        gt_subject_matter = ALICE_STEP_ONE_MAPPING[alice_step_one]
        if gt_subject_matter.nil?
          errors << "Row #{index + 2} (#{patent_number}): Unknown Alice Step One value: '#{alice_step_one}'"
          gt_subject_matter = alice_step_one # Keep original if not mapped
        end

        gt_inventive_concept = ALICE_STEP_TWO_MAPPING[alice_step_two]
        if gt_inventive_concept.nil?
          errors << "Row #{index + 2} (#{patent_number}): Unknown Alice Step Two value: '#{alice_step_two}'"
          gt_inventive_concept = alice_step_two # Keep original if not mapped
        end

        gt_overall_eligibility = OVERALL_ELIGIBILITY_MAPPING[overall_eligibility]
        if gt_overall_eligibility.nil?
          errors << "Row #{index + 2} (#{patent_number}): Unknown Overall Eligibility value: '#{overall_eligibility}'"
          gt_overall_eligibility = overall_eligibility # Keep original if not mapped
        end

        # Write transformed row
        csv << [
          patent_number.strip,
          claim_number.to_i,
          claim_text&.strip,
          abstract&.strip,
          gt_subject_matter,
          gt_inventive_concept,
          gt_overall_eligibility
        ]

        transformed_count += 1

        # Progress indicator
        if (index + 1) % 10 == 0
          puts "  Processed #{index + 1}/#{csv_data.length} records..."
        end

      rescue => e
        errors << "Row #{index + 2}: #{e.message}"
      end
    end
  end

  puts "\n" + "=" * 80
  puts "✅ Transformation Complete!"
  puts "📝 Transformed: #{transformed_count} records"
  puts "📁 Output file: #{output_file}"

  if errors.any?
    puts "\n⚠️  Warnings/Errors (#{errors.length}):"
    errors.first(10).each { |err| puts "  - #{err}" }
    puts "  ... (#{errors.length - 10} more)" if errors.length > 10
  end

  # Show sample transformation
  puts "\n📋 Sample Transformation (First Record):"
  first_original = csv_data.first
  puts "  Original:"
  puts "    Patent Number: #{first_original['Patent Number']}"
  puts "    Alice Step One: #{first_original['Alice Step One']}"
  puts "    Alice Step Two: #{first_original['Alice Step Two']}"
  puts "    Overall Eligibility: #{first_original['Overall Eligibility']}"

  first_transformed = CSV.read(output_file, headers: true, encoding: 'UTF-8').first
  puts "  Transformed:"
  puts "    patent_number: #{first_transformed['patent_number']}"
  puts "    gt_subject_matter: #{first_transformed['gt_subject_matter']}"
  puts "    gt_inventive_concept: #{first_transformed['gt_inventive_concept']}"
  puts "    gt_overall_eligibility: #{first_transformed['gt_overall_eligibility']}"

  # Show value distribution
  puts "\n📊 Value Distribution:"
  transformed_csv = CSV.read(output_file, headers: true, encoding: 'UTF-8')

  puts "  gt_subject_matter:"
  transformed_csv.group_by { |r| r['gt_subject_matter'] }.each do |val, rows|
    puts "    #{val}: #{rows.length} patents"
  end

  puts "  gt_inventive_concept:"
  transformed_csv.group_by { |r| r['gt_inventive_concept'] }.each do |val, rows|
    puts "    #{val}: #{rows.length} patents"
  end

  puts "  gt_overall_eligibility:"
  transformed_csv.group_by { |r| r['gt_overall_eligibility'] }.each do |val, rows|
    puts "    #{val}: #{rows.length} patents"
  end

  puts "\n🎉 Ready to import into Rails database!"
  puts "Next step: Run 'ruby scripts/import_transformed_ground_truth.rb'"

rescue => e
  puts "❌ Fatal error: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
