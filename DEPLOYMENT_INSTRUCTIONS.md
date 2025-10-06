# Deployment Instructions - Ground Truth Redesign

## Overview
This deployment implements a complete architecture redesign to eliminate backend rules and enable direct JSON comparison between ground truth and LLM outputs.

## Railway Deployment Steps

### Step 1: Wait for Automatic Deployment
Railway is currently deploying the code changes automatically from GitHub push.

Monitor at: https://railway.com/project/74334dab-1659-498e-a674-51093d87392c

### Step 2: Upload Ground Truth CSV to Railway

The transformed CSV file needs to be added to Railway:

```bash
# Copy the transformed CSV to Railway
railway run bash -c "mkdir -p /app/groundt && cat > /app/groundt/gt_transformed_for_llm.csv" < groundt/gt_transformed_for_llm.csv
```

### Step 3: Import Ground Truth Data

```bash
railway run rails runner scripts/import_new_ground_truth.rb
```

### Step 4: Test the System

Visit: https://validity101demo-production.up.railway.app/prompt_engine/prompts/1/eval_sets/2?mode=run_form

Login: admin / secret123

Select 2-3 patents and run evaluation.

