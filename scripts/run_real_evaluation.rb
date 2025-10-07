# Actually run the evaluation properly
require_relative '../config/environment'

# Connect to Railway DB
ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  url: "postgresql://postgres:MaGEOMlVhGMIWlHCpJCaVaHpsfNLnEnR@crossover.proxy.rlwy.net:20657/railway"
)

eval_set = PromptEngine::EvalSet.find(2)
prompt = PromptEngine::Prompt.find(1)

# Create new eval run
eval_run = PromptEngine::EvalRun.create!(
  eval_set: eval_set,
  prompt_version: prompt.versions.first,
  status: :running,
  started_at: Time.current
)

puts "Created eval run ID: #{eval_run.id}"
puts "Processing #{eval_set.test_cases.count} test cases..."

test_cases = eval_set.test_cases.order(:id)
processed = 0
passed_count = 0

test_cases.each_with_index do |test_case, index|
  input_vars = JSON.parse(test_case.input_variables)
  patent_id = input_vars['patent_id']

  puts "\n[#{index + 1}/#{test_cases.count}] #{patent_id}..."

  begin
    # Use the actual service
    result_json = AI::ValidityAnalysis::Service.new(
      claim_text: input_vars['claim_text'],
      abstract: input_vars['abstract'],
      patent_id: patent_id,
      claim_number: input_vars['claim_number']
    ).call

    actual_output = result_json.to_json
    expected_output = test_case.expected_output

    is_pass = (actual_output == expected_output)
    passed_count += 1 if is_pass

    # Insert result
    PromptEngine::EvalResult.create!(
      eval_run: eval_run,
      test_case: test_case,
      output: actual_output,
      passed: is_pass
    )

    puts "  #{is_pass ? '✓ PASS' : '✗ FAIL'}"

  rescue => e
    puts "  ✗ ERROR: #{e.message}"
    PromptEngine::EvalResult.create!(
      eval_run: eval_run,
      test_case: test_case,
      output: nil,
      passed: false,
      error_message: e.message
    )
  end

  processed += 1
  sleep 0.5  # Rate limiting
end

# Mark as completed
eval_run.update!(
  status: :completed,
  completed_at: Time.current
)

pass_rate = (passed_count.to_f / processed * 100).round(2)
puts "\n" + "="*60
puts "COMPLETED!"
puts "Total: #{processed}"
puts "Passed: #{passed_count}"
puts "Failed: #{processed - passed_count}"
puts "Pass Rate: #{pass_rate}%"
puts "\nView at: https://validity101demo-production.up.railway.app/prompt_engine/prompts/1/eval_sets/2/metrics?run_id=#{eval_run.id}"
