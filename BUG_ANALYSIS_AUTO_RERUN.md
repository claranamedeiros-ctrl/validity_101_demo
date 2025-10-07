# Bug Analysis: Automatic Re-run of Old Evaluations

## Incident Report

**What Happened:**
User ran evaluation #6 with 50 patents. After completion, evaluation #5 (older run) automatically started processing again without user action. This caused unexpected OpenAI API charges.

## Root Cause Investigation

### Checked for Automatic Triggers:
1. ✅ **EvaluationJob** - Does NOT enqueue itself
2. ✅ **Controller** - Only enqueues job when user clicks "Run Evaluation"
3. ✅ **ActiveJob retry_on** - Commented out (not active)
4. ✅ **Recurring jobs** - Only cleanup job in `config/recurring.yml`

### Most Likely Cause: AsyncAdapter + Stuck Jobs

**Before Solid Queue was implemented:**
- System used AsyncAdapter (in-process job execution)
- Jobs that timed out or failed were left in database as "pending"
- When new job was enqueued, worker picked up BOTH:
  - New job (run #6)
  - Old stuck job (run #5) from previous failed attempt

**This explains:**
- Why old run (#5) started after new run (#6) completed
- Why it happened without user action
- Why it's so dangerous (old jobs can retry endlessly)

## Fix: Solid Queue Implementation

**With Solid Queue (now implemented):**
- Jobs stored in dedicated `solid_queue_*` tables
- Failed jobs are explicitly marked as "failed" not "pending"
- No automatic retry unless explicitly configured
- Clear separation between new and old jobs

## Prevention Measures

### 1. Clean Up Stuck Jobs (IMMEDIATE ACTION NEEDED)

Before enabling Solid Queue worker, clean the database:

```bash
# Connect to Railway database
railway run --service validity_101_demo rails console

# In Rails console:
# Check for any pending/running evaluation jobs
PromptEngine::EvalRun.where(status: ['pending', 'running']).each do |run|
  puts "EvalRun ##{run.id} - Status: #{run.status} - Created: #{run.created_at}"
end

# Mark old stuck runs as failed
PromptEngine::EvalRun.where(status: ['pending', 'running']).where('created_at < ?', 1.hour.ago).update_all(status: 'failed', error_message: 'Stuck job - auto-failed during migration to Solid Queue')

# Verify cleanup
puts "Remaining pending/running runs: #{PromptEngine::EvalRun.where(status: ['pending', 'running']).count}"
```

### 2. Add Safeguard in EvaluationJob

Prevent re-processing of old evaluations by checking creation time:

```ruby
# In app/jobs/evaluation_job.rb - add at start of perform method:
def perform(eval_run_id, selected_patent_ids = nil)
  @eval_run = PromptEngine::EvalRun.find(eval_run_id)

  # SAFEGUARD: Don't process eval runs older than 1 hour that are not already running
  if @eval_run.created_at < 1.hour.ago && @eval_run.status != 'running'
    Rails.logger.warn "Skipping old eval run ##{eval_run_id} (created #{@eval_run.created_at})"
    @eval_run.update!(
      status: :failed,
      error_message: "Eval run too old - possible stuck job"
    )
    return
  end

  # ... rest of existing code
end
```

### 3. Monitor Solid Queue Failed Jobs

Add to your monitoring:

```bash
# Check for failed jobs
railway run --service validity_101_demo rails runner "puts SolidQueue::Job.where(finished_at: nil).where('created_at < ?', 10.minutes.ago).count"
```

### 4. Disable Auto-Retry in Solid Queue

In `config/queue.yml`, ensure no automatic retry is configured:

```yaml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: 1
      polling_interval: 0.1
      # NO retry configuration here
```

## Testing the Fix

After Solid Queue worker is deployed:

1. Run a small evaluation (3 patents)
2. Let it complete
3. Wait 5 minutes
4. Check logs for any automatic re-runs
5. Verify no old jobs are processing

## Emergency Stop Procedure

If automatic re-run happens again:

1. **Stop worker service immediately:**
   ```bash
   # In Railway dashboard, pause/stop the worker service
   ```

2. **Kill running jobs:**
   ```bash
   railway run --service validity_101_demo rails runner "
     SolidQueue::Job.where(finished_at: nil).update_all(
       finished_at: Time.current,
       failed_at: Time.current
     )
   "
   ```

3. **Investigate:**
   - Check eval_runs table for status
   - Check solid_queue_jobs for stuck entries
   - Check logs for who enqueued the job

## Status

- ❌ **Bug occurred:** Yes (before Solid Queue)
- ✅ **Root cause identified:** AsyncAdapter + stuck jobs
- ✅ **Fix implemented:** Solid Queue (proper job lifecycle)
- ⏳ **Database cleanup:** PENDING (need to run cleanup script)
- ⏳ **Safeguard added:** PENDING (need to add age check to job)
- ⏳ **Testing:** PENDING (after worker deploys)

## Next Steps

1. Wait for worker service to finish deploying
2. Run database cleanup script before starting worker
3. Add safeguard to EvaluationJob
4. Test with small evaluation
5. Monitor for 24 hours to confirm fix

---

**CRITICAL:** Do NOT enable worker service until database cleanup is complete, or old stuck jobs may run again!
