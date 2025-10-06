# Implementation Plan - Ground Truth Format Change

## Analysis of New Ground Truth CSV

**File:** `groundt/Ground_truth.csv`
- **Total Patents:** 50
- **Missing:** Patent numbers - NOT in the CSV!
- **Has:** Claim Text, Abstract, Alice Step One, Alice Step Two, Overall Eligibility

**Values Found:**
- Alice Step One: "Abstract", "Not Abstract"
- Alice Step Two: "IC Found", "No IC Found", "N/A"
- Overall Eligibility: "Eligible", "Ineligible"

## 🚨 CRITICAL ISSUE: NO PATENT NUMBERS IN CSV!

The new CSV does NOT contain patent numbers or claim numbers! We need to:
1. Either add patent numbers to the CSV
2. Or generate synthetic IDs for the 50 patents

## Schema Mapping Required

### From CSV → To LLM Schema

**Alice Step One → subject_matter:**
- "Abstract" → "Abstract"
- "Not Abstract" → "Not Abstract/Not Natural Phenomenon"
- "Natural Phenomenon" → "Natural Phenomenon" (if any)

**Alice Step Two → inventive_concept:**
- "No IC Found" → "No"
- "IC Found" → "Yes"
- "N/A" → "-"

**Overall Eligibility → overall_eligibility:**
- "Eligible" → "Eligible"
- "Ineligible" → "Ineligible"

## Files That Need Changes

### 1. Ground Truth Import Script
**File:** `scripts/convert_ground_truth.rb` or NEW script
**Changes:**
- Read from `Ground_truth.csv`
- Generate patent numbers (US + sequential number?)
- Transform Alice Step values to LLM schema format
- Output to new CSV with columns: patent_number, claim_number, claim_text, abstract, gt_subject_matter, gt_inventive_concept, gt_overall_eligibility

### 2. Service Layer - Remove Backend Rules
**File:** `app/services/ai/validity_analysis/service.rb`
**Changes:**
- Line 62-79: Remove forced_value transformations
- Return raw LLM outputs directly
- Keep overall_eligibility calculation (it's needed!)
- Remove validity_score forcing logic

### 3. Evaluation Job
**File:** `app/jobs/evaluation_job.rb`
**Changes:**
- Line 66: Change to compare full JSON structure
- Line 81-86: Remove validity_score from stored results
- Update grading to compare 3 fields: subject_matter, inventive_concept, overall_eligibility

### 4. Controller Ground Truth Loading
**File:** `app/controllers/prompt_engine/eval_sets_controller.rb`
**Changes:**
- Line 310: Update CSV filename
- Line 318-327: Remove inventive_concept mapping (use raw values)
- Update to expect new CSV format with claim_text and abstract

### 5. UI - Metrics View
**File:** `app/views/prompt_engine/eval_sets/metrics.html.erb`
**Changes:**
- Remove validity_score column entirely
- Keep only: Patent ID, Expected (3 fields), Actual (3 fields), Pass/Fail

### 6. UI - Validities Show View
**File:** `app/views/validities/show.html.erb`
**Changes:**
- Check if validity_score is displayed
- Remove if present

### 7. Import Production Data Script
**File:** `scripts/import_production_data.rb`
**Changes:**
- Update to use new CSV format
- Update column mappings

## Database Changes Required

### Clear Old Test Data
```ruby
PromptEngine::EvalResult.destroy_all
PromptEngine::EvalRun.destroy_all
PromptEngine::TestCase.destroy_all
```

### Import New Test Cases
- Read from transformed CSV
- Create TestCase records with new input_variables format
- Store claim_text and abstract in input_variables

## Implementation Order (Critical for Dependencies)

1. ✅ Create new transformation script (adds patent numbers)
2. ✅ Transform CSV to proper format
3. ✅ Update controller CSV loading logic
4. ✅ Remove backend rules from service.rb
5. ✅ Update evaluation_job.rb grading
6. ✅ Update UI views (remove validity_score)
7. ✅ Clear database test data
8. ✅ Import new ground truth data
9. ✅ Test with sample evaluation

## Risk Mitigation

- Backup current database before clearing
- Keep old CSV files as backup
- Test transformation script on first 5 records before full run
- Verify each change doesn't break dependent code
