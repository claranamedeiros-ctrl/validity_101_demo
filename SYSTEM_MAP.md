# Complete Rails System Map - Patent Validity Analysis

## System Overview

**Purpose:** AI-powered patent validity analysis using Alice Test methodology with GPT-4o
**Framework:** Ruby on Rails 7 + PromptEngine gem + RubyLLM gem
**Database:** PostgreSQL (Railway)
**LLM:** OpenAI GPT-4o

---

## User Flows

### Flow 1: Run Alice Test (Main Flow)

**URL Path:** `/prompt_engine` → Navigate to eval set → Click "Run Alice Test"

```
1. User Login (admin/secret123)
   ↓
2. Homepage: /prompt_engine
   ↓
3. View Prompts List
   ↓
4. Click "validity-101-agent"
   ↓
5. View Eval Sets
   ↓
6. Click "Patent Validity Test Cases - 50 Patents"
   ↓
7. Patent Selection Page: /prompt_engine/prompts/1/eval_sets/2?mode=run_form
   - Shows all 50 patents with checkboxes
   - Can select 1-50 patents
   ↓
8. Click "Run Evaluation"
   ↓
9. Evaluation Job Starts (background)
   - Calls GPT-4o for each patent
   - Stores results in database
   ↓
10. Results Page: /prompt_engine/prompts/1/eval_sets/2?mode=results
    - Shows pass/fail for each patent
    ↓
11. Metrics Page: /prompt_engine/prompts/1/eval_sets/2/metrics
    - Detailed comparison: Expected vs Actual
    - 3 columns: Subject Matter, Inventive Concept, Overall Eligibility
```

### Flow 2: Single Patent Analysis

**URL Path:** `/validities/new`

```
1. User visits /validities/new
   ↓
2. Form with fields:
   - Patent Number (e.g., US6128415A)
   - Claim Number (e.g., 1)
   - Claim Text (full text)
   - Abstract (full text)
   ↓
3. Submit form
   ↓
4. Controller calls service.rb
   ↓
5. Service calls GPT-4o
   ↓
6. Results displayed: /validity/:id
   - Subject Matter
   - Inventive Concept
   - Overall Eligibility
   - Validity Score
```

---

## Component Architecture

### Controllers

#### 1. ValiditiesController
**File:** `app/controllers/validities_controller.rb`
**Routes:**
- `GET /validities/new` - Single patent analysis form
- `POST /validities` - Process single patent
- `GET /validity/:id` - Show results

**Actions:**
```ruby
def new
  # Show form for single patent analysis
end

def create
  # 1. Get form params (patent_number, claim_number, claim_text, abstract)
  # 2. Call Ai::ValidityAnalysis::Service
  # 3. Store result in session
  # 4. Redirect to show page
end

def show
  # Display analysis results from session
end
```

#### 2. PromptEngine::EvalSetsController
**File:** `app/controllers/prompt_engine/eval_sets_controller.rb`
**Routes:** (Mounted from PromptEngine gem)
- `GET /prompt_engine/prompts/:prompt_id/eval_sets/:id?mode=run_form` - Patent selection
- `POST /prompt_engine/prompts/:prompt_id/eval_sets/:id/run` - Start evaluation
- `GET /prompt_engine/prompts/:prompt_id/eval_sets/:id?mode=results` - View results
- `GET /prompt_engine/prompts/:prompt_id/eval_sets/:id/metrics` - Detailed metrics

**Key Actions:**
```ruby
def show
  # Displays patent selection form or results based on ?mode param
  # mode=run_form: Shows checkboxes for 50 patents
  # mode=results: Shows pass/fail summary
end

def run_evaluation
  # 1. Get selected patent IDs from params
  # 2. Create EvalRun record
  # 3. Enqueue EvaluationJob
  # 4. Redirect to results page
end

def metrics
  # 1. Load ground truth from CSV
  # 2. Load eval results from database
  # 3. Build comparison table (Expected vs Actual)
end
```

### Jobs

#### EvaluationJob
**File:** `app/jobs/evaluation_job.rb`
**Purpose:** Process evaluation runs in background

**Flow:**
```ruby
def perform(eval_run_id, selected_patent_ids = nil)
  # 1. Load eval_run and test_cases
  # 2. Filter by selected_patent_ids if provided
  # 3. For each test_case:
  #    a. Parse input_variables (patent_id, claim_number, claim_text, abstract)
  #    b. Call Ai::ValidityAnalysis::Service
  #    c. Compare result to expected_output (JSON with 3 fields)
  #    d. Store EvalResult (actual_output, passed)
  # 4. Update eval_run with final counts (passed_count, failed_count)
end

private

def grade_result(actual_output, expected_output)
  # Compare 3 fields: subject_matter, inventive_concept, overall_eligibility
  # All 3 must match (case-insensitive) for pass
  # Returns: true/false
end
```

### Services

#### Ai::ValidityAnalysis::Service
**File:** `app/services/ai/validity_analysis/service.rb`
**Purpose:** Main service that calls GPT-4o and processes results

**Flow:**
```ruby
def call(patent_number:, claim_number:, claim_text:, abstract:)
  # 1. Render prompt from PromptEngine
  rendered = PromptEngine.render("validity-101-agent", variables: {...})

  # 2. Build JSON schema
  schema = {
    subject_matter: { enum: ["Abstract", "Natural Phenomenon", "Not Abstract/Not Natural Phenomenon"] },
    inventive_concept: { enum: ["No", "Yes", "-"] },
    validity_score: { minimum: 1, maximum: 5 }
  }

  # 3. Call OpenAI GPT-4o
  chat = RubyLLM.chat(provider: "openai", model: "gpt-4o")
  response = chat.with_schema(schema)
                 .with_temperature(0.1)
                 .with_instructions(system_message)
                 .ask(user_message)

  # 4. Calculate overall_eligibility from Alice Test logic
  overall_eligibility = if subject_matter == "Not Abstract/Not Natural Phenomenon"
    "Eligible"
  elsif inventive_concept == "Yes"
    "Eligible"
  else
    "Ineligible"
  end

  # 5. Return RAW LLM outputs (NO forced values!)
  {
    status: :success,
    patent_number: patent_number,
    claim_number: claim_number,
    subject_matter: raw[:subject_matter],
    inventive_concept: raw[:inventive_concept],
    validity_score: raw[:validity_score],
    overall_eligibility: overall_eligibility
  }
end
```

**Key Points:**
- ✅ Calls real GPT-4o API
- ✅ Enforces JSON schema with enums
- ✅ Returns RAW values (no backend mapping)
- ✅ Calculates overall_eligibility from Alice Test logic

### Views

#### 1. Patent Selection (run_form.html.erb)
**File:** `app/views/prompt_engine/eval_sets/run_form.html.erb`
**Displays:**
- List of 50 patents with checkboxes
- "Select All" / "Deselect All" buttons
- "Run Evaluation" button

**Data Source:** TestCase records from database

#### 2. Results View (results.html.erb)
**File:** `app/views/prompt_engine/eval_sets/results.html.erb`
**Displays:**
- Pass/fail summary
- List of patents with pass/fail status
- Link to detailed metrics

**Data Source:** EvalResult records

#### 3. Metrics View (metrics.html.erb)
**File:** `app/views/prompt_engine/eval_sets/metrics.html.erb`
**Displays:**
- Detailed comparison table
- 3 columns: Subject Matter, Inventive Concept, Overall Eligibility
- Each shows: Expected | Actual | Match?
- NO validity_score column

**Data Source:**
- EvalResult records (actual output)
- Ground truth CSV (expected output)

#### 4. Single Patent Form (validities/new.html.erb)
**File:** `app/views/validities/new.html.erb`
**Displays:**
- Form fields for single patent analysis
- Patent number, claim number, claim text, abstract

#### 5. Single Patent Results (validities/show.html.erb)
**File:** `app/views/validities/show.html.erb`
**Displays:**
- Analysis results for single patent
- All 4 fields (including validity_score)

---

## Database Schema

### PromptEngine Tables

#### prompt_engine_prompts
```sql
id, name, description, system_message, content, model, temperature, max_tokens, status
```
**Key Record:**
- name: "validity-101-agent"
- system_message: From backend/system.erb
- content: From backend/user.erb

#### prompt_engine_eval_sets
```sql
id, prompt_id, name, description, grader_type, grader_config
```
**Key Record:**
- name: "Patent Validity Test Cases - 50 Patents"
- grader_type: "exact_match"

#### prompt_engine_test_cases
```sql
id, eval_set_id, input_variables, expected_output, description
```
**50 Records - One per patent:**
```json
input_variables: {
  "patent_id": "US6128415A",
  "claim_number": 1,
  "claim_text": "A device profile for describing...",
  "abstract": "Device profiles conventionally..."
}

expected_output: {
  "subject_matter": "Abstract",
  "inventive_concept": "No",
  "overall_eligibility": "Ineligible"
}
```

#### prompt_engine_eval_runs
```sql
id, eval_set_id, status, passed_count, failed_count, total_count, metadata, created_at
```
**Created each time user clicks "Run Evaluation"**

#### prompt_engine_eval_results
```sql
id, eval_run_id, test_case_id, actual_output, passed, created_at
```
**One per patent per evaluation run:**
```json
actual_output: {
  "subject_matter": "Abstract",
  "inventive_concept": "No",
  "overall_eligibility": "Ineligible"
}
passed: true/false
```

---

## Data Flow: Complete Evaluation

```
1. User selects patents (UI)
   ↓
2. Controller creates EvalRun
   ↓
3. EvaluationJob enqueued
   ↓
4. For each patent:

   a. Load TestCase from database
      - patent_id: US6128415A
      - claim_text: "A device profile..."
      - abstract: "Device profiles..."

   b. Call Service
      ↓
   c. Service calls GPT-4o API
      Request: {
        "patent_id": "US6128415A",
        "claim_text": "...",
        "abstract": "..."
      }
      ↓
   d. GPT-4o returns structured JSON
      Response: {
        "subject_matter": "Abstract",
        "inventive_concept": "No",
        "validity_score": 2
      }
      ↓
   e. Service calculates overall_eligibility
      Alice Test Logic: Abstract + No IC = Ineligible
      ↓
   f. Service returns result
      {
        "subject_matter": "Abstract",
        "inventive_concept": "No",
        "overall_eligibility": "Ineligible",
        "validity_score": 2
      }
      ↓
   g. EvaluationJob compares to expected
      Expected: {"subject_matter": "Abstract", "inventive_concept": "No", "overall_eligibility": "Ineligible"}
      Actual:   {"subject_matter": "Abstract", "inventive_concept": "No", "overall_eligibility": "Ineligible"}
      Match: ALL 3 fields match → PASS ✓
      ↓
   h. Store EvalResult
      actual_output: JSON (3 fields)
      passed: true

5. Update EvalRun
   passed_count: 17
   failed_count: 3
   total_count: 20
   status: completed
   ↓
6. User views results
   - Results page: 85% pass rate
   - Metrics page: Detailed comparison
```

---

## Key Configuration Files

### 1. Ground Truth CSV
**File:** `groundt/gt_transformed_for_llm.csv`
**Columns:** patent_number, claim_number, claim_text, abstract, gt_subject_matter, gt_inventive_concept, gt_overall_eligibility
**Rows:** 50 patents
**Loaded by:** Controller's `load_ground_truth_data` method

### 2. System Prompt
**File:** `backend/system.erb`
**Contains:** Instructions for GPT-4o on Alice Test methodology
**Loaded by:** PromptEngine.render()

### 3. User Prompt Template
**File:** `backend/user.erb`
**Contains:** Template with {{patent_id}}, {{claim_text}}, etc.
**Loaded by:** PromptEngine.render()

### 4. Import Script
**File:** `scripts/import_new_ground_truth.rb`
**Purpose:** Load 50 patents from CSV into database
**Run with:** `railway run rails runner scripts/import_new_ground_truth.rb`

---

## Environment Variables (Railway)

```env
DATABASE_URL=postgresql://...
OPENAI_API_KEY=sk-...
RAILS_ENV=production
RAILS_MASTER_KEY=...
SECRET_KEY_BASE=...
```

---

## Testing Checklist

### ✅ Completed Tests
- [x] CSV transformation (50 patents)
- [x] Evaluation comparison logic
- [x] Controller CSV loading
- [x] Service output structure
- [x] UI display values

### ⏳ Pending Tests
- [ ] Full evaluation flow (with real GPT-4o)
- [ ] Patent selection UI
- [ ] Results viewing
- [ ] Metrics page display
- [ ] Error handling
- [ ] Single patent analysis flow

---

**System Status:** 🟢 Code Complete, Ready for End-to-End Testing
**Next Step:** Deploy to Railway and run import script
