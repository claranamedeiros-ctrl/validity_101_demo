#!/usr/bin/env ruby
# Cleanup script for stuck evaluation runs before enabling Solid Queue worker

puts "=" * 80
puts "CLEANUP: Stuck Evaluation Jobs"
puts "=" * 80
puts ""

# Find all pending/running eval runs
stuck_runs = PromptEngine::EvalRun.where(status: ['pending', 'running'])

puts "Found #{stuck_runs.count} eval runs in pending/running status:"
puts ""

stuck_runs.each do |run|
  age_hours = ((Time.current - run.created_at) / 1.hour).round(1)
  puts "EvalRun ##{run.id}"
  puts "  Status: #{run.status}"
  puts "  Created: #{run.created_at}"
  puts "  Age: #{age_hours} hours ago"
  puts "  Total count: #{run.total_count}"
  puts ""
end

if stuck_runs.any?
  puts "=" * 80
  puts "MARKING OLD RUNS AS FAILED"
  puts "=" * 80
  puts ""

  # Mark runs older than 1 hour as failed
  old_runs = stuck_runs.where('created_at < ?', 1.hour.ago)

  if old_runs.any?
    puts "Marking #{old_runs.count} old runs (>1 hour) as failed..."

    old_runs.each do |run|
      run.update!(
        status: 'failed',
        error_message: 'Stuck job - auto-failed during migration to Solid Queue',
        completed_at: Time.current
      )
      puts "  ✅ Marked EvalRun ##{run.id} as failed"
    end

    puts ""
    puts "Cleanup complete!"
  else
    puts "No runs older than 1 hour found."
  end

  # Check for recent runs (within last hour)
  recent_runs = stuck_runs.where('created_at >= ?', 1.hour.ago)
  if recent_runs.any?
    puts ""
    puts "⚠️  WARNING: #{recent_runs.count} recent runs (< 1 hour old) still pending/running:"
    recent_runs.each do |run|
      puts "  - EvalRun ##{run.id} (#{run.created_at})"
    end
    puts ""
    puts "These may be legitimately running. Check manually if needed."
  end
else
  puts "✅ No stuck jobs found! Database is clean."
end

puts ""
puts "=" * 80
puts "FINAL STATUS"
puts "=" * 80
pending_count = PromptEngine::EvalRun.where(status: 'pending').count
running_count = PromptEngine::EvalRun.where(status: 'running').count
failed_count = PromptEngine::EvalRun.where(status: 'failed').count
completed_count = PromptEngine::EvalRun.where(status: 'completed').count

puts "Pending: #{pending_count}"
puts "Running: #{running_count}"
puts "Failed: #{failed_count}"
puts "Completed: #{completed_count}"
puts ""

if pending_count == 0 && running_count == 0
  puts "✅ Safe to start Solid Queue worker!"
elsif running_count > 0
  puts "⚠️  Warning: #{running_count} runs still marked as 'running'"
  puts "   If these are old, mark them as failed manually"
else
  puts "⚠️  Warning: #{pending_count} runs still marked as 'pending'"
  puts "   These may start processing when worker starts!"
end

puts "=" * 80
