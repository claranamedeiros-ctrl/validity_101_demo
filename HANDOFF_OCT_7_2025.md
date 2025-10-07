# Handoff Document - October 7, 2025 Solid Queue Attempt

## Current Status: UNTESTED

Everything below is what was implemented. **NONE OF IT HAS BEEN TESTED YET.**

## What Was Attempted
Properly implement Solid Queue with separate Railway worker service to fix AsyncAdapter hanging on 50 patents.

## Changes Made (Commits: d0b5c60, b8ad4c1, 589e714)

### 1. Added Solid Queue
- Added `gem "solid_queue"` to Gemfile
- Ran `bundle exec rails solid_queue:install`
- Created: `config/queue.yml`, `config/recurring.yml`, `db/queue_schema.rb`, `bin/jobs`

### 2. Configured Production
- Added to `config/environments/production.rb`:
  ```ruby
  config.active_job.queue_adapter = :solid_queue
  ```

### 3. Fixed Procfile
- **Removed**: `release: bundle exec rails db:migrate`
- **Why**: Was causing worker service build to fail (database not accessible during build)
- **Now**: Only `web: bundle exec rails server -b 0.0.0.0 -p $PORT`

### 4. Fixed railway.toml
- **Changed**: `startCommand = "bundle exec rails server..."`
- **To**: `startCommand = "${START_COMMAND:-bundle exec rails server...}"`
- **Why**: Allows worker service to override with `START_COMMAND=bin/jobs`

### 5. Created Worker Service in Railway
- **Service name**: `validity_101_demo-worker`
- **Repository**: Same as web (claranamedeiros-ctrl/validity_101_demo)
- **Environment variables**:
  - `DATABASE_URL` - Referenced from PostgreSQL database
  - `OPENAI_API_KEY` - Copied from web service
  - `RAILS_ENV` - Set to `production`
  - `SECRET_KEY_BASE` - Copied from web service
  - `START_COMMAND` - Set to `bin/jobs`

### 6. Investigated Auto-Rerun Bug
- **Created**: `BUG_ANALYSIS_AUTO_RERUN.md`
- **Root Cause**: AsyncAdapter left jobs in "pending/running" state, worker picked up old stuck jobs
- **Cleanup**: Created `scripts/cleanup_stuck_jobs.rb` and ran it
- **Result**: 0 stuck jobs found (database was clean)

### 7. Documentation
- **Created**: `SOLID_QUEUE_RAILWAY_SETUP.md` - Full deployment guide
- **Created**: `BUG_ANALYSIS_AUTO_RERUN.md` - Bug investigation
- **Created**: `scripts/cleanup_stuck_jobs.rb` - Database cleanup script

## Git Commits
```
589e714 - Fix railway.toml to support different start commands per service
b8ad4c1 - Remove release command from Procfile - causes worker build to fail
d0b5c60 - Add Solid Queue for background job processing
```

## Testing Checklist (NOT DONE YET)

### Step 1: Verify Worker Started
```bash
railway logs --service validity_101_demo-worker | grep -i "solid"
```
**Expected**:
```
[SolidQueue] Starting Dispatcher...
[SolidQueue] Starting Worker...
```

**If you see Puma instead**, worker is still broken.

### Step 2: Test Small Evaluation (3-5 patents)
1. Go to app: `https://validity101demo-production.up.railway.app/prompt_engine`
2. Click "Run Alice Test"
3. Select 3-5 patents
4. Click "Run Evaluation"

**Check web logs**:
```bash
railway logs --service validity_101_demo
```
Should see: `[ActiveJob] Enqueued EvaluationJob`

**Check worker logs**:
```bash
railway logs --service validity_101_demo-worker
```
Should see: `[ActiveJob] Performing EvaluationJob`

### Step 3: Monitor for Auto-Reruns
- Wait 10 minutes after evaluation completes
- Check if any jobs start automatically
- Check database: `railway run rails runner "puts PromptEngine::EvalRun.where(status: 'running').count"`

### Step 4: Test 50 Patents
- Only if steps 1-3 succeed
- Select all 50 patents
- Should complete without hanging/timeout

## If This Fails

### Diagnostic Commands
```bash
# Check worker status
railway logs --service validity_101_demo-worker | head -50

# Check if worker is using correct start command
railway run --service validity_101_demo-worker env | grep START_COMMAND

# Check Rails environment
railway run --service validity_101_demo-worker env | grep RAILS_ENV

# Check for stuck jobs
railway run rails runner "puts PromptEngine::EvalRun.where(status: ['pending', 'running']).count"
```

### Alternative Solutions

#### Option A: Try Good Job Instead
```ruby
# Gemfile
gem 'good_job'

# production.rb
config.active_job.queue_adapter = :good_job

# Start command
START_COMMAND=bundle exec good_job start
```

#### Option B: Try Sidekiq + Redis
- Add Redis database to Railway
- Use Sidekiq gem
- More complex but proven solution

#### Option C: Accept AsyncAdapter Limitations
- Remove Solid Queue
- Process patents in batches of 10
- Multiple smaller runs instead of one big run

#### Option D: Different Platform
- Heroku: Better multi-process support
- Render: Native background worker support
- Fly.io: Multiple process types in single deployment

## Current Deployment Status

**As of handoff:**
- Web service: Building/Deploying (after latest commits)
- Worker service: Building/Deploying (after adding START_COMMAND variable)
- Database: Clean (no stuck jobs)

## What Could Go Wrong

1. **Worker still runs Puma instead of bin/jobs**
   - railway.toml variable substitution doesn't work
   - START_COMMAND not being recognized

2. **Worker can't connect to database**
   - DATABASE_URL not properly referenced
   - Missing encryption keys

3. **Solid Queue tables don't exist**
   - Migrations not run (we removed release command)
   - Need to manually run: `railway run rails db:migrate`

4. **Jobs enqueue but never process**
   - Worker service not actually running
   - Wrong queue name
   - Worker polling wrong database

5. **Auto-rerun bug still happens**
   - Different root cause than identified
   - Solid Queue has own retry mechanism we didn't account for

## How to Rollback

If everything fails:

```bash
# Rollback to before Solid Queue
git revert 589e714 b8ad4c1 d0b5c60
git push origin main

# Or hard reset
git reset --hard 50ab856  # Last commit before Solid Queue
git push --force origin main

# Delete worker service from Railway dashboard
```

## Files to Check If Debugging

1. `config/environments/production.rb` - Active job adapter setting
2. `railway.toml` - Start command configuration
3. `config/queue.yml` - Solid Queue configuration
4. `Procfile` - Should only have web command now
5. `bin/jobs` - Worker start script (should be executable)
6. Railway dashboard - Both services' environment variables

## Questions to Answer During Testing

- [ ] Does worker service start with SolidQueue?
- [ ] Do jobs enqueue to Solid Queue tables?
- [ ] Does worker pick up and process jobs?
- [ ] Can 3-5 patents complete successfully?
- [ ] Does progress tracking work?
- [ ] Can 50 patents run without timeout?
- [ ] Do any automatic reruns occur?

## Expected Log Patterns

**Good (Working)**:
```
# Web service
[ActiveJob] Enqueued EvaluationJob (Job ID: abc123) to SolidQueue(default)

# Worker service
[SolidQueue] Starting Dispatcher(pid=123, ...)
[SolidQueue] Starting Worker(pid=124, ...)
[ActiveJob] [EvaluationJob] [abc123] Performing EvaluationJob
[ActiveJob] [EvaluationJob] [abc123] Performed EvaluationJob (Duration: 45s)
```

**Bad (Broken)**:
```
# Worker running Puma instead
=> Booting Puma
=> Rails 8.0.3 application starting in development

# Jobs not being picked up
[ActiveJob] Enqueued EvaluationJob
(no matching "Performing" log in worker)

# Worker can't connect
PG::ConnectionBad: could not translate host name
```

## Final Notes

This is the **third attempt** at fixing the AsyncAdapter issue:
1. **First attempt**: Previous developer - failed, left broken
2. **Second attempt**: (Unknown) - ended up with current mess
3. **Third attempt**: This one - outcome unknown

**Key difference this time**:
- Properly researched Railway limitations (no Procfile worker support)
- Created separate worker service (correct Railway pattern)
- Used environment variable for start command override
- Cleaned database of stuck jobs
- Documented everything

**If this fails, consider**: Maybe AsyncAdapter isn't the real problem. Maybe it's timeouts, API rate limits, or database connection pooling.

---

**Next Developer**: Read this BEFORE testing. Don't assume anything works until you verify each step.
