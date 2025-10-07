# Simpler version - Run via local Rails, insert to production DB
require_relative '../config/environment'

# Override database to use Railway production
ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  url: "postgresql://postgres:MaGEOMlVhGMIWlHCpJCaVaHpsfNLnEnR@crossover.proxy.rlwy.net:20657/railway"
)

# Create eval run
eval_set = PromptEngine::EvalSet.find(2)
prompt = PromptEngine::Prompt.find(1)

eval_run = PromptEngine::EvalRun.create!(
  eval_set: eval_set,
  prompt_version: prompt.versions.first,
  status: :running,
  started_at: Time.current,
  metadata: {}
)

puts "Created eval run ID: #{eval_run.id}"
puts "Starting evaluation of #{eval_set.test_cases.count} patents..."

# Run the evaluation using the existing service
require_relative '../app/services/custom_evaluation_runner'

runner = CustomEvaluationRunner.new(
  eval_run: eval_run,
  test_case_ids: eval_set.test_cases.pluck(:id),
  openai_api_key: ENV['OPENAI_API_KEY']
)

runner.run!

puts "\nCOMPLETED!"
puts "View results at:"
puts "https://validity101demo-production.up.railway.app/prompt_engine/prompts/1/eval_sets/2/metrics?run_id=#{eval_run.id}"
