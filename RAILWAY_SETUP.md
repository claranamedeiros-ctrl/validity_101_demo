# Railway Production Setup Guide

## Current Issue
The app is deployed but missing Prompt ID 1 and Eval Set ID 2 in production database.

**Error:** `Couldn't find PromptEngine::Prompt with 'id'="1"`

## Solution: Run Production Data Import

### Step 1: Access Railway CLI

Install Railway CLI if you haven't:
```bash
npm install -g @railway/cli
```

Login to Railway:
```bash
railway login
```

Link to your project:
```bash
railway link 74334dab-1659-498e-a674-51093d87392c
```

### Step 2: Run the Import Script

Execute the production data import script on Railway:

```bash
railway run rails runner scripts/import_production_data.rb
```

This will:
1. ✅ Create Prompt "validity-101-agent" (loads from `backend/system.erb` and `backend/user.erb`)
2. ✅ Create Prompt Version v1
3. ✅ Create Eval Set "Patent Validity Test Cases" with `exact_match` grading
4. ✅ Import 50 patent test cases from `groundt/gt_aligned_normalized_test.csv`

### Step 3: Verify Setup

After import completes, check the output for:
- Prompt ID (should print the created ID)
- Eval Set ID (should print the created ID)
- Number of test cases created (should be 50)

### Step 4: Update URLs if Needed

If the created IDs are different from 1 and 2, update your application URLs:

**Current hardcoded URLs:**
- `/prompt_engine/prompts/1/eval_sets/2` (in various views)
- Update these to use the actual IDs created

**Better approach:** Use dynamic routing
```ruby
# Instead of hardcoded /prompts/1/eval_sets/2
# Use: prompt_eval_set_path(@prompt, @eval_set)
```

## Alternative: Upload Backend Files to Railway

If `backend/*.erb` files are not in git (they shouldn't be), you need to upload them:

### Option A: Temporary Environment Variables
```bash
railway variables set SYSTEM_PROMPT="$(cat backend/system.erb)"
railway variables set USER_PROMPT="$(cat backend/user.erb)"
```

Then modify import script to read from ENV.

### Option B: Use Railway Volume
Upload backend files to a Railway volume for persistent storage.

### Option C: Inline the Prompts
Copy the content from `backend/system.erb` and `backend/user.erb` directly into the import script (not recommended for sensitive IP).

## Troubleshooting

### Issue: "File not found: backend/system.erb"
**Solution:** The backend files are not in git. Use Option A, B, or C above.

### Issue: "Ground truth file not found"
**Solution:** Ensure `groundt/gt_aligned_normalized_test.csv` is in git and deployed.

### Issue: "Test cases already exist"
**Solution:** Script clears existing test cases before import. Safe to re-run.

## Post-Import Verification

Visit your Railway app:
```
https://your-app.railway.app/prompt_engine
```

You should see:
1. Prompt: "validity-101-agent"
2. Eval Set: "Patent Validity Test Cases" (50 test cases)
3. Ability to run evaluations from the UI

## Backend Alignment Checklist

Verify 100% alignment with production backend:

- [x] Schema enums match `backend/schema.rb`
  - `subject_matter: ['Abstract', 'Natural Phenomenon', 'Not Abstract/Not Natural Phenomenon']`
  - `inventive_concept: ['No', 'Yes', '-']`

- [x] Mapping classes used correctly
  - `SubjectMatter.new(llm_subject_matter:)` maps enum to symbol
  - `InventiveConcept.new(llm_inventive_concept:, subject_matter:)` maps and handles patentable

- [x] Forced values applied
  - `inventive_concept.forced_value` - forces `:skipped` if patentable
  - `validity_score.forced_value` - forces 3 or 2 if inconsistent

- [x] Overall eligibility rules match `backend/overall_eligibility.rb:12-22`

- [x] System/user prompts from `backend/*.erb` files

## Quick Commands

```bash
# Deploy latest code
git push origin main

# Run import on Railway
railway run rails runner scripts/import_production_data.rb

# Check Railway logs
railway logs

# Open Rails console on Railway
railway run rails console

# Check database
railway run rails runner "puts PromptEngine::Prompt.count"
```
