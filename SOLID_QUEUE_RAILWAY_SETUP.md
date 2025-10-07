# Solid Queue Setup on Railway - Complete Guide

## ✅ What We Fixed

**Problem:** AsyncAdapter runs jobs in-process, causing the application to hang when processing 50 patents.

**Solution:** Implemented Solid Queue with a separate worker service on Railway.

## 📋 Changes Made Locally

1. ✅ Added `solid_queue` gem to Gemfile
2. ✅ Ran `bundle exec rails solid_queue:install` which created:
   - `config/queue.yml` - Solid Queue configuration
   - `config/recurring.yml` - For scheduled jobs (not used yet)
   - `db/queue_schema.rb` - Database schema for job tables
   - `bin/jobs` - Script to start Solid Queue supervisor
3. ✅ Configured production.rb with `config.active_job.queue_adapter = :solid_queue`

## 🚀 Railway Deployment Steps

### Step 1: Commit and Push Changes

```bash
git add .
git commit -m "Add Solid Queue for background job processing"
git push origin main
```

### Step 2: Deploy Web Service (Automatic)

Railway will automatically detect the changes and redeploy the web service. This will:
- Install the solid_queue gem
- Run database migrations (creates Solid Queue tables)
- Start the Rails web server

**Wait for this deployment to complete before proceeding.**

### Step 3: Create Worker Service in Railway Dashboard

**IMPORTANT:** Railway's Procfile only runs ONE process. You MUST create a separate service for the worker.

1. Go to your Railway project: https://railway.com/project/74334dab-1659-498e-a674-51093d87392c
2. Click **"+ New"** button
3. Select **"GitHub Repo"**
4. Choose the **SAME** repository: `validity_101_demo`
5. Name the service: **`validity_101_demo-worker`**

### Step 4: Configure Worker Service

Once the worker service is created:

1. Go to the worker service **Settings**
2. Scroll to **"Deploy"** section
3. Find **"Custom Start Command"**
4. Set it to:
   ```
   bin/jobs
   ```
5. Click **"Save"**

### Step 5: Copy Environment Variables to Worker

The worker needs access to the same database and environment variables as the web service.

1. Go to your **web service** (`validity_101_demo`)
2. Click on **"Variables"** tab
3. Copy all the following variables
4. Go to the **worker service** (`validity_101_demo-worker`)
5. Click on **"Variables"** tab
6. Add the same variables:

**Required Variables:**
- `DATABASE_URL` (automatically set by Railway if you link the database)
- `OPENAI_API_KEY`
- `RAILS_ENV` = `production`
- `SECRET_KEY_BASE`
- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` (if set)
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` (if set)
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` (if set)

**Tip:** You can also link the PostgreSQL database to the worker service:
1. In worker service settings
2. Click "Connect" under "Databases"
3. Select your PostgreSQL database
4. Railway will automatically set `DATABASE_URL`

### Step 6: Deploy Worker Service

1. In the worker service, click **"Deploy"**
2. Railway will pull the same repository and start the worker

### Step 7: Verify Both Services Are Running

Check the logs for each service:

**Web Service Logs:**
```bash
railway logs --service validity_101_demo
```

You should see:
```
Puma starting in single mode...
* Listening on http://0.0.0.0:8080
```

**Worker Service Logs:**
```bash
railway logs --service validity_101_demo-worker
```

You should see:
```
[SolidQueue] Starting Dispatcher(pid=123, hostname=..., metadata={:polling_interval=>1, :batch_size=>500})
[SolidQueue] Starting Worker(pid=124, hostname=..., metadata={:queues=>"*", :threads=>3, :polling_interval=>0.1})
```

### Step 8: Test Background Jobs

1. Go to your Railway app URL: `https://validity101demo-production.up.railway.app/prompt_engine`
2. Navigate to "Run Alice Test"
3. Select a few patents (start with 3-5 to test)
4. Click "Run Evaluation"

**Check Web Service Logs:**
```
[ActiveJob] Enqueued EvaluationJob (Job ID: xxx) to SolidQueue(default)
```

**Check Worker Service Logs:**
```
[ActiveJob] [EvaluationJob] [xxx] Performing EvaluationJob
[ActiveJob] [EvaluationJob] [xxx] Performed EvaluationJob
```

## 🎯 How It Works

### Before (AsyncAdapter - BROKEN)
```
User clicks "Run Evaluation"
  ↓
Web Server receives request
  ↓
EvaluationJob runs IN-PROCESS (blocks web server)
  ↓
Processes 50 patents (takes 10+ minutes)
  ↓
Request times out, job never completes
```

### After (Solid Queue - FIXED)
```
User clicks "Run Evaluation"
  ↓
Web Server receives request
  ↓
EvaluationJob enqueued to Solid Queue database
  ↓
Web Server returns immediately (user sees "Processing...")
  ↓
Worker Service picks up job from queue
  ↓
Worker processes patents in background
  ↓
Results stored in database
  ↓
User refreshes page to see results
```

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                  Railway Web Service                     │
│                                                           │
│  - Handles HTTP requests                                 │
│  - Enqueues jobs to Solid Queue                          │
│  - Does NOT process jobs                                 │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
        ┌─────────────────────────┐
        │   PostgreSQL Database    │
        │                          │
        │  - Application data      │
        │  - Solid Queue tables:   │
        │    * solid_queue_jobs    │
        │    * solid_queue_ready_  │
        │      executions          │
        │    * solid_queue_        │
        │      scheduled_executions│
        └─────────────┬────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                Railway Worker Service                    │
│                                                           │
│  - Polls database for new jobs                           │
│  - Executes EvaluationJob                                │
│  - Calls OpenAI API                                      │
│  - Stores results                                        │
└───────────────────────────────────────────────────────────┘
```

## 🔍 Troubleshooting

### Worker Service Not Starting

**Check:**
1. Custom start command is set to `bin/jobs` (no `bundle exec` needed)
2. All environment variables are copied from web service
3. DATABASE_URL is set correctly
4. Check worker logs for errors

### Jobs Not Being Processed

**Check:**
1. Web service logs show `Enqueued EvaluationJob`
2. Worker service logs show `Performing EvaluationJob`
3. Both services are using the same DATABASE_URL
4. Worker service is actually running (check Railway dashboard)

### Database Errors

**Common issues:**
- Worker service doesn't have DATABASE_URL set
- Wrong database URL (web and worker must use same database)
- Migrations not run (run `railway run bundle exec rails db:migrate` on web service)

## ✅ Success Indicators

You'll know everything is working when:

1. ✅ Web service starts without errors
2. ✅ Worker service starts and shows `[SolidQueue] Starting...` logs
3. ✅ Running evaluation shows `Enqueued EvaluationJob` in web logs
4. ✅ Worker logs show `Performing EvaluationJob`
5. ✅ Evaluation completes and results appear in UI
6. ✅ You can run 50 patents without timeout/hanging

## 📝 Important Notes

- **DO NOT** add a `worker:` line to Procfile - Railway ignores it
- **DO NOT** use Puma's solid_queue plugin - it causes fork() issues on cloud platforms
- **ALWAYS** create a separate service for the worker
- **REMEMBER** to copy all environment variables to the worker service

## 🎓 What We Learned

1. **Railway Procfile limitation** - Only runs ONE process (the `web:` line)
2. **Solution** - Create separate services from the same repository
3. **Solid Queue benefits** - No Redis needed, uses your existing PostgreSQL database
4. **Worker isolation** - Worker service runs independently, won't crash web service

---

**Previous developer's mistake:** Tried to use Procfile `worker:` line, which Railway doesn't support.

**Our fix:** Created proper two-service architecture as recommended by Railway documentation.
