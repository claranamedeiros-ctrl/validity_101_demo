# Railway Worker Setup for Solid Queue

## Problem
Railway Procfile only runs ONE process. The `worker:` line does nothing.

## Solution: Manual Railway Configuration

### Step 1: Check Current Deployment
1. Go to Railway dashboard
2. Check if deployment succeeded
3. Health check should PASS now

### Step 2: Set Worker Start Command
1. In Railway dashboard, go to your service
2. Click "Settings"
3. Scroll to "Deploy" section
4. Find "Custom Start Command"
5. **IMPORTANT:** Leave it BLANK for web service (uses Procfile web command)

### Step 3: Create Separate Worker Service (REQUIRED)
1. In Railway project, click "+ New"
2. Select "GitHub Repo"
3. Choose the SAME repository: validity_101_demo
4. Name it: "validity_101_demo-worker"
5. Go to Settings → Deploy
6. Set Custom Start Command: `bundle exec rake solid_queue:start`
7. Go to Settings → Environment Variables
8. Copy ALL environment variables from web service:
   - DATABASE_URL
   - OPENAI_API_KEY
   - RAILS_ENV=production
   - SECRET_KEY_BASE
   - All encryption keys

### Step 4: Remove Procfile Worker Line
Since Railway ignores it anyway:
```bash
# Edit Procfile to remove worker line
web: bundle exec rails server -b 0.0.0.0 -p $PORT
release: bundle exec rails db:prepare && bundle exec rails db:seed
```

## Alternative: Use AsyncAdapter (Current State)
If you DON'T want to set up worker service:
- Jobs will run in web process (blocking)
- Works for LOW VOLUME testing
- Will hang/fail for 50 patents

## Verification
After worker service is running, check logs:
```bash
railway logs --service validity_101_demo-worker
```

You should see:
```
[SolidQueue] Starting supervisor...
[SolidQueue] Worker started
```

Then run patents and check:
```bash
railway logs --service validity_101_demo
```

You should see:
```
[ActiveJob] Enqueued EvaluationJob to SolidQueue(default)
[ActiveJob] Performing EvaluationJob
```
