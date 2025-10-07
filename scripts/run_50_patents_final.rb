# Run 50 patents using EvaluationJob directly
require_relative '../config/environment'

# Override database to use Railway production
ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  url: "postgresql://postgres:MaGEOMlVhGMIWlHCpJCaVaHpsfNLnEnR@crossover.proxy.rlwy.net:20657/railway"
)

# Get eval run that was already created (ID: 4)
eval_run = PromptEngine::EvalRun.find(4)
puts "Using existing eval run ID: #{eval_run.id}"

# Get all test case IDs
test_case_ids = eval_run.eval_set.test_cases.pluck(:id)
puts "Processing #{test_case_ids.count} patents..."

# Run the job synchronously (in-process, no background worker needed)
EvaluationJob.perform_now(eval_run.id, test_case_ids)

puts "\nCOMPLETED!"
puts "View results at:"
puts "https://validity101demo-production.up.railway.app/prompt_engine/prompts/1/eval_sets/2/metrics?run_id=#{eval_run.id}"
