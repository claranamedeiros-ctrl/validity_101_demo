require_relative '../config/environment'

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  url: "postgresql://postgres:MaGEOMlVhGMIWlHCpJCaVaHpsfNLnEnR@crossover.proxy.rlwy.net:20657/railway"
)

run = PromptEngine::EvalRun.find(4)
results = PromptEngine::EvalResult.where(eval_run_id: 4).order(:id)

puts "Eval Run #4 Results:"
puts "Status: #{run.status}"
puts "Total: #{results.count}"
puts "Passed: #{results.where(passed: true).count}"
puts "Failed: #{results.where(passed: false).count}"
puts "\nPass Rate: #{(results.where(passed: true).count.to_f / results.count * 100).round(2)}%"
