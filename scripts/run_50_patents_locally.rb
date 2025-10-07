# Run 50 patents locally and insert results directly into Railway database
# This bypasses the need to run on Railway which has timeout issues

require 'pg'
require 'json'

# Railway database connection
DB_URL = "postgresql://postgres:MaGEOMlVhGMIWlHCpJCaVaHpsfNLnEnR@crossover.proxy.rlwy.net:20657/railway"
OPENAI_KEY = ENV['OPENAI_API_KEY']

puts "Connecting to Railway database..."
conn = PG.connect(DB_URL)

# Get the eval set and test cases
eval_set_id = 2
prompt_id = 1

puts "Fetching test cases..."
test_cases = conn.exec_params(
  "SELECT id, input_variables, expected_output FROM prompt_engine_test_cases WHERE eval_set_id = $1 ORDER BY id",
  [eval_set_id]
)

puts "Found #{test_cases.count} test cases"

# Create eval run
run_result = conn.exec_params(
  "INSERT INTO prompt_engine_eval_runs (eval_set_id, prompt_version_id, status, started_at, created_at, updated_at, metadata)
   VALUES ($1, 1, 'running', NOW(), NOW(), NOW(), '{}')
   RETURNING id",
  [eval_set_id]
)
eval_run_id = run_result[0]['id']
puts "Created eval run ID: #{eval_run_id}"

# Get prompt
prompt_result = conn.exec_params("SELECT system_message, user_message FROM prompt_engine_prompts WHERE id = $1", [prompt_id])
system_message = prompt_result[0]['system_message']
user_message = prompt_result[0]['user_message']

processed = 0
passed = 0
failed = 0

test_cases.each do |test_case|
  test_case_id = test_case['id']
  input_vars = JSON.parse(test_case['input_variables'])
  expected_output = test_case['expected_output']

  patent_id = input_vars['patent_id']
  claim_number = input_vars['claim_number']
  claim_text = input_vars['claim_text']
  abstract = input_vars['abstract']

  puts "\n[#{processed + 1}/#{test_cases.count}] Processing #{patent_id}..."

  begin
    # Call OpenAI API
    require 'net/http'
    require 'uri'

    uri = URI.parse("https://api.openai.com/v1/chat/completions")
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request["Authorization"] = "Bearer #{OPENAI_KEY}"

    # Render user message with variables
    rendered_user = user_message
      .gsub('{{patent_id}}', patent_id)
      .gsub('{{claim_number}}', claim_number.to_s)
      .gsub('{{claim_text}}', claim_text)
      .gsub('{{abstract}}', abstract)

    request.body = JSON.dump({
      "model" => "gpt-5",
      "messages" => [
        {"role" => "system", "content" => system_message},
        {"role" => "user", "content" => rendered_user}
      ],
      "temperature" => 0
    })

    req_options = {
      use_ssl: uri.scheme == "https",
      read_timeout: 180,
      open_timeout: 30
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    if response.code.to_i == 200
      result = JSON.parse(response.body)
      llm_output = result.dig('choices', 0, 'message', 'content')

      # Parse JSON output
      llm_json = JSON.parse(llm_output)
      actual_output = JSON.dump(llm_json)

      # Compare outputs
      is_pass = (actual_output == expected_output)

      if is_pass
        passed += 1
        puts "  ✓ PASS"
      else
        failed += 1
        puts "  ✗ FAIL"
        puts "  Expected: #{expected_output[0..100]}"
        puts "  Actual:   #{actual_output[0..100]}"
      end

      # Insert result
      conn.exec_params(
        "INSERT INTO prompt_engine_eval_results
         (eval_run_id, test_case_id, output, passed, error_message, created_at, updated_at)
         VALUES ($1, $2, $3, $4, NULL, NOW(), NOW())",
        [eval_run_id, test_case_id, actual_output, is_pass]
      )

    else
      # API error
      failed += 1
      error_msg = "OpenAI API error: #{response.code} - #{response.body[0..200]}"
      puts "  ✗ ERROR: #{error_msg}"

      conn.exec_params(
        "INSERT INTO prompt_engine_eval_results
         (eval_run_id, test_case_id, output, passed, error_message, created_at, updated_at)
         VALUES ($1, $2, NULL, false, $3, NOW(), NOW())",
        [eval_run_id, test_case_id, error_msg]
      )
    end

  rescue => e
    # Processing error
    failed += 1
    error_msg = "Error: #{e.message}"
    puts "  ✗ ERROR: #{error_msg}"

    conn.exec_params(
      "INSERT INTO prompt_engine_eval_results
       (eval_run_id, test_case_id, output, passed, error_message, created_at, updated_at)
       VALUES ($1, $2, NULL, false, $3, NOW(), NOW())",
      [eval_run_id, test_case_id, error_msg]
    )
  end

  processed += 1

  # Small delay to avoid rate limits
  sleep 1
end

# Update eval run as completed
pass_rate = (passed.to_f / processed * 100).round(2)
conn.exec_params(
  "UPDATE prompt_engine_eval_runs
   SET status = 'completed',
       completed_at = NOW(),
       updated_at = NOW(),
       metadata = jsonb_set(metadata, '{pass_rate}', $1::text::jsonb)
   WHERE id = $2",
  [pass_rate.to_s, eval_run_id]
)

puts "\n" + "="*60
puts "COMPLETED!"
puts "="*60
puts "Total: #{processed}"
puts "Passed: #{passed}"
puts "Failed: #{failed}"
puts "Pass Rate: #{pass_rate}%"
puts "\nView results at:"
puts "https://validity101demo-production.up.railway.app/prompt_engine/prompts/1/eval_sets/2/metrics?run_id=#{eval_run_id}"

conn.close
