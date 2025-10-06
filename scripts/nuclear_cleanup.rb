#!/usr/bin/env ruby
# NUCLEAR CLEANUP - Delete ALL old evaluation data across ALL eval sets

puts "🧹 NUCLEAR CLEANUP - Deleting ALL Old Evaluation Data"
puts "=" * 80

# Step 1: Delete ALL EvalResults
if defined?(PromptEngine::EvalResult)
  count = PromptEngine::EvalResult.count
  puts "Deleting #{count} EvalResults..."
  PromptEngine::EvalResult.delete_all
  puts "✅ Deleted #{count} EvalResults"
end

# Step 2: Delete ALL EvalRuns
if defined?(PromptEngine::EvalRun)
  count = PromptEngine::EvalRun.count
  puts "Deleting #{count} EvalRuns..."
  PromptEngine::EvalRun.delete_all
  puts "✅ Deleted #{count} EvalRuns"
end

# Step 3: Delete ALL TestCases (we'll re-import fresh)
if defined?(PromptEngine::TestCase)
  count = PromptEngine::TestCase.count
  puts "Deleting #{count} TestCases..."
  PromptEngine::TestCase.delete_all
  puts "✅ Deleted #{count} TestCases"
end

# Step 4: Delete ALL old EvalSets except the one we want
if defined?(PromptEngine::EvalSet)
  total = PromptEngine::EvalSet.count
  puts "Found #{total} EvalSets"

  # Keep only the main one for validity-101-agent
  prompt = PromptEngine::Prompt.find_by(name: "validity-101-agent")

  if prompt
    old_eval_sets = PromptEngine::EvalSet.where.not(prompt_id: prompt.id)
    old_eval_sets.destroy_all
    puts "✅ Deleted eval sets from other prompts"

    # Delete all but keep the structure for reimport
    current_eval_sets = PromptEngine::EvalSet.where(prompt_id: prompt.id)
    puts "Found #{current_eval_sets.count} eval sets for validity-101-agent"
  end
end

puts ""
puts "=" * 80
puts "✅ CLEANUP COMPLETE!"
puts ""
puts "Current State:"
puts "  EvalResults: #{PromptEngine::EvalResult.count}"
puts "  EvalRuns: #{PromptEngine::EvalRun.count}"
puts "  TestCases: #{PromptEngine::TestCase.count}"
puts "  EvalSets: #{PromptEngine::EvalSet.count}"
puts ""
puts "🔄 Next Step: Run import script to load fresh 50 patents"
puts "   railway run rails runner scripts/import_new_ground_truth.rb"
