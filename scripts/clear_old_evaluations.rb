#!/usr/bin/env ruby
# Clear all old evaluation data to start fresh

puts "Clearing all old evaluation data..."
puts "=" * 80

# Delete in correct order (foreign key constraints)
if defined?(PromptEngine::EvalResult)
  count = PromptEngine::EvalResult.count
  PromptEngine::EvalResult.destroy_all
  puts "✅ Deleted #{count} EvalResults"
end

if defined?(PromptEngine::EvalRun)
  count = PromptEngine::EvalRun.count
  PromptEngine::EvalRun.destroy_all
  puts "✅ Deleted #{count} EvalRuns"
end

# Don't delete TestCases - we need those!
puts "\n✅ Old evaluation data cleared!"
puts "TestCases preserved (#{PromptEngine::TestCase.count} patents)"
puts "\nReady for fresh evaluation runs!"
