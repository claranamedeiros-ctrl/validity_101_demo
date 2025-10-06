#!/usr/bin/env ruby
# Fix duplicate eval sets - keep only the one with 50 test cases

puts "Fixing Duplicate Eval Sets"
puts "=" * 80

prompt = PromptEngine::Prompt.find_by(name: "validity-101-agent")

if prompt
  eval_sets = prompt.eval_sets.order(created_at: :asc)
  puts "Found #{eval_sets.count} eval sets for validity-101-agent:"
  puts ""

  eval_sets.each do |es|
    test_count = es.test_cases.count
    puts "  ID #{es.id}: #{es.name} - #{test_count} test cases"
  end

  puts ""

  # Keep the one with 50 test cases, delete others
  correct_eval_set = eval_sets.find { |es| es.test_cases.count == 50 }

  if correct_eval_set
    puts "✅ Keeping eval set ID #{correct_eval_set.id} with 50 test cases"
    puts ""

    # Delete the others
    eval_sets.where.not(id: correct_eval_set.id).each do |es|
      puts "Deleting eval set ID #{es.id}: #{es.name} (#{es.test_cases.count} test cases)"
      es.destroy
      puts "  ✅ Deleted"
    end
  else
    puts "❌ No eval set found with 50 test cases!"
  end

  puts ""
  puts "Final state:"
  prompt.reload.eval_sets.each do |es|
    puts "  ID #{es.id}: #{es.name} - #{es.test_cases.count} test cases"
  end
else
  puts "❌ Prompt 'validity-101-agent' not found!"
end

puts ""
puts "=" * 80
puts "✅ Done!"
