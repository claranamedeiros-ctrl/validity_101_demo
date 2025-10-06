# Manual Testing Guide - Railway Deployment

## Prerequisites

✅ Railway deployment complete
✅ Import script run: `railway run rails runner scripts/import_new_ground_truth.rb`
✅ 50 patents loaded in database

---

## Test Scenario 1: Run Alice Test (Main Flow)

### Objective
Test the complete evaluation flow with 2-3 patents

### Steps

1. **Navigate to Application**
   ```
   URL: https://validity101demo-production.up.railway.app/prompt_engine
   Login: admin / secret123
   ```
   **Expected:** Homepage with "Prompts" list

2. **Select Prompt**
   - Click on "validity-101-agent"
   **Expected:** Prompt details page showing eval sets

3. **Navigate to Patent Selection**
   - Click on "Patent Validity Test Cases - 50 Patents"
   - URL should be: `/prompt_engine/prompts/1/eval_sets/2`
   - Click "Run Alice Test" button OR add `?mode=run_form` to URL
   **Expected:** Patent selection page with 50 checkboxes

4. **Verify Patent List**
   - Check that all 50 patents are displayed
   - Look for patents: US6128415A, US7644019B2, US7346545B2
   **Expected:** List shows patent numbers with checkboxes

5. **Select Test Patents**
   - Check boxes for 3 patents:
     * US6128415A (Claim 1)
     * US7644019B2 (Claim 1)
     * US7346545B2 (Claim 1)
   **Expected:** Checkboxes selected

6. **Run Evaluation**
   - Click "Run Evaluation" button
   **Expected:**
   - Redirects to results page
   - Shows "Evaluation running..." or similar message

7. **Wait for Completion**
   - Evaluation should take ~30-60 seconds for 3 patents
   - Refresh page if needed
   **Expected:** Status changes to "completed"

8. **View Results Summary**
   - Should automatically show results or click "View Results"
   **Expected:**
   ```
   Total Tests: 3
   Passed: X
   Failed: Y
   Pass Rate: Z%
   ```

9. **View Detailed Metrics**
   - Click "View Metrics" or navigate to `/metrics`
   **Expected:** Detailed comparison table

10. **Verify Metrics Display**
    - Check table has 4 columns:
      * Patent ID
      * Subject Matter (Expected | Actual)
      * Inventive Concept (Expected | Actual)
      * Overall Eligibility (Expected | Actual)
    - **NO validity_score column**
    **Expected:** 3 columns showing Expected | Actual format

11. **Verify Values Display**
    - Check that values are displayed as:
      * "Abstract" (NOT "abstract")
      * "No" (NOT "uninventive")
      * "Ineligible" (NOT lowercase)
    **Expected:** Raw schema values with proper capitalization

12. **Check Match Indicators**
    - Green highlight for matches
    - Red highlight for mismatches
    **Expected:** Visual indicators working

### Success Criteria
✅ All 3 patents evaluated
✅ Results displayed correctly
✅ Metrics show 3 columns (no validity_score)
✅ Values match schema format
✅ Pass/fail indicators correct

---

## Test Scenario 2: Single Patent Analysis

### Objective
Test individual patent analysis flow

### Steps

1. **Navigate to Form**
   ```
   URL: https://validity101demo-production.up.railway.app/validities/new
   ```
   **Expected:** Form with 4 fields

2. **Fill in Patent Data**
   ```
   Patent Number: US6128415A
   Claim Number: 1
   Claim Text: A device profile for describing properties of a device in a digital image reproduction system to capture, transform or render an image, said device profile comprising: first data for describing a device dependent transformation of color information content of the image to a device independent color space; and second data for describing a device dependent transformation of spatial information content of the image in said device independent color space.
   Abstract: Device profiles conventionally describe properties of a device or element within a digital image processing system that capture, transform or render color components of an image. An improved device profile includes both chromatic characteristic information and spatial characteristic information.
   ```

3. **Submit Form**
   - Click "Analyze Patent"
   **Expected:** Redirects to results page

4. **Verify Results Display**
   **Expected output for US6128415A:**
   ```
   Subject Matter: Abstract
   Inventive Concept: No
   Overall Eligibility: Ineligible
   Validity Score: 1 or 2 (low score for ineligible)
   ```

5. **Check Alice Test Logic**
   - Abstract + No IC should = Ineligible
   **Expected:** Overall eligibility calculated correctly

### Success Criteria
✅ Form accepts input
✅ GPT-4o called successfully
✅ Results display all 4 fields
✅ Alice Test logic correct

---

## Test Scenario 3: Select All Patents

### Objective
Test evaluation with all 50 patents

### Steps

1. **Navigate to Patent Selection**
   - Go to eval set run form

2. **Select All**
   - Click "Select All" button
   **Expected:** All 50 checkboxes checked

3. **Run Full Evaluation**
   - Click "Run Evaluation"
   **Expected:** Starts processing 50 patents

4. **Monitor Progress**
   - Evaluation should take ~5-10 minutes
   - Can monitor with: `railway logs --tail 100`
   **Expected:** See log messages for each patent

5. **View Final Results**
   - Check pass rate
   - Review metrics for any failures
   **Expected:** Results for all 50 patents

### Success Criteria
✅ All 50 patents processed
✅ No timeouts or errors
✅ Pass rate calculated correctly
✅ Metrics page loads with 50 rows

---

## Test Scenario 4: Error Handling

### Objective
Verify system handles errors gracefully

### Test 4A: Invalid Patent Number

1. **Use Single Patent Form**
   - Patent Number: INVALID123
   - Fill other fields
   - Submit

**Expected:** Error message or graceful handling

### Test 4B: Missing Claim Text

1. **Use Single Patent Form**
   - Leave Claim Text empty
   - Fill other fields
   - Submit

**Expected:** Validation error or required field message

### Test 4C: OpenAI API Error (Simulate)

1. **Check Logs During Evaluation**
   ```
   railway logs --tail 50
   ```
   - Look for any API errors
   **Expected:** Errors logged but don't crash system

### Success Criteria
✅ Errors handled gracefully
✅ User sees meaningful error messages
✅ System doesn't crash
✅ Failed patents marked correctly

---

## Test Scenario 5: UI Navigation

### Objective
Verify all navigation links work

### Steps

1. **Homepage → Prompts**
   - Click "Prompts"
   **Expected:** List of prompts

2. **Prompts → Eval Sets**
   - Click on prompt
   **Expected:** Eval sets list

3. **Eval Sets → Run Form**
   - Click "Run Alice Test"
   **Expected:** Patent selection

4. **Results → Metrics**
   - After evaluation, click "View Metrics"
   **Expected:** Detailed metrics table

5. **Metrics → Results**
   - Click "Back to Results" or "View Results"
   **Expected:** Summary page

6. **Back to Eval Set**
   - Click "Back to Eval Set"
   **Expected:** Eval set details

### Success Criteria
✅ All links work
✅ No 404 errors
✅ Breadcrumbs/navigation clear

---

## Test Scenario 6: Data Verification

### Objective
Verify data accuracy against known cases

### Known Ground Truth Cases

#### Test Case 1: US6128415A
**Expected:**
- Subject Matter: Abstract
- Inventive Concept: No
- Overall Eligibility: Ineligible

**How to Verify:**
1. Run evaluation on this patent
2. Check metrics page
3. Compare actual vs expected

#### Test Case 2: US9098876B2 (if in dataset)
Check if this patent has different values and verify correct display

### Success Criteria
✅ Actual output matches expected for known cases
✅ Ground truth displays correctly
✅ Comparison accurate

---

## Test Scenario 7: Performance Testing

### Objective
Verify system performs adequately

### Benchmarks

**Single Patent Analysis:**
- Expected time: 5-10 seconds
- Includes: API call + processing

**3 Patent Evaluation:**
- Expected time: 30-60 seconds
- Sequential processing

**50 Patent Evaluation:**
- Expected time: 5-10 minutes
- Background job processing

### Steps

1. **Time Single Patent**
   - Note start time
   - Submit single patent form
   - Note end time
   **Expected:** < 15 seconds

2. **Monitor Background Job**
   - Start 3-patent evaluation
   - Watch logs: `railway logs --tail`
   **Expected:** See progress logs

3. **Check Database Queries**
   - Look for N+1 queries in logs
   **Expected:** Efficient queries

### Success Criteria
✅ Response times acceptable
✅ No timeouts
✅ Progress visible
✅ Background jobs complete

---

## Debugging Commands

### Check Application Status
```bash
railway logs --tail 100
```

### Check Database
```bash
railway run rails runner "puts PromptEngine::TestCase.count"
railway run rails runner "puts PromptEngine::EvalRun.count"
railway run rails runner "puts PromptEngine::EvalResult.count"
```

### Check Ground Truth
```bash
railway run rails runner "
tc = PromptEngine::TestCase.first
puts 'Patent: ' + JSON.parse(tc.input_variables)['patent_id']
puts 'Expected: ' + tc.expected_output
"
```

### Re-run Import
```bash
railway run rails runner scripts/import_new_ground_truth.rb
```

### Check OpenAI API Key
```bash
railway vars
```

---

## Common Issues & Solutions

### Issue: "No test cases found"
**Solution:** Run import script
```bash
railway run rails runner scripts/import_new_ground_truth.rb
```

### Issue: "OpenAI API error"
**Solution:** Check API key is set
```bash
railway vars | grep OPENAI
```

### Issue: "Evaluation stuck"
**Solution:** Check job status
```bash
railway logs | grep "EvaluationJob"
```

### Issue: "Wrong values displayed"
**Solution:** Check CSV file loaded
```bash
railway run ls -la /app/groundt/
```

---

## Test Checklist

### Before Testing
- [ ] Railway deployed
- [ ] Database migrated
- [ ] Import script run
- [ ] 50 patents loaded
- [ ] OpenAI API key set

### During Testing
- [ ] Test Scenario 1: Run Alice Test (3 patents)
- [ ] Test Scenario 2: Single Patent Analysis
- [ ] Test Scenario 3: Select All (50 patents)
- [ ] Test Scenario 4: Error Handling
- [ ] Test Scenario 5: UI Navigation
- [ ] Test Scenario 6: Data Verification
- [ ] Test Scenario 7: Performance

### After Testing
- [ ] Document any issues found
- [ ] Verify pass rates make sense
- [ ] Check for any UI bugs
- [ ] Confirm system is production-ready

---

## Expected Results Summary

### Metrics Page Should Show:
```
┌──────────────┬──────────────────────────────────────┬─────────┐
│ Patent ID    │ Expected | Actual                    │ Match?  │
├──────────────┼──────────────────────────────────────┼─────────┤
│ US6128415A   │                                      │         │
│              │ Subject Matter:                      │         │
│              │ Abstract | Abstract                  │ ✓       │
│              │                                      │         │
│              │ Inventive Concept:                   │         │
│              │ No | No                              │ ✓       │
│              │                                      │         │
│              │ Overall Eligibility:                 │         │
│              │ Ineligible | Ineligible              │ ✓       │
└──────────────┴──────────────────────────────────────┴─────────┘
```

### What You Should NOT See:
- ❌ Validity Score column
- ❌ Lowercase values ("abstract", "uninventive")
- ❌ Old backend mappings
- ❌ 4 columns instead of 3

---

**Ready for Testing!** 🚀
