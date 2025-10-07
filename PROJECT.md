# Patent Validity Evaluation System - Project Architecture & Decisions

## Table of Contents
1. [System Overview](#system-overview)
2. [Technology Stack - What We're Actually Using](#technology-stack)
3. [The Ground Truth Transformation Story](#ground-truth-transformation)
4. [PromptEngine Integration - Workarounds & Custom Solutions](#promptengine-integration)
5. [RubyLLM Integration - The Structured Output Challenge](#rubyllm-integration)
6. [GPT-5 vs GPT-4 - Different Approaches Required](#gpt-5-vs-gpt-4)
7. [Key Architecture Decisions](#key-decisions)
8. [What We Built From Scratch](#custom-implementations)

---

## System Overview

**What This System Does:**
- Evaluates patent claims for validity using GPT-5 (OpenAI's reasoning model)
- Compares AI analysis against expert human ground truth
- Implements the Alice Test methodology (2-step patent eligibility test)
- Provides a UI for running evaluations and viewing results

**The Core Challenge:**
Making three separate systems work together:
1. **PromptEngine gem** - Third-party prompt management system (not designed for our use case)
2. **RubyLLM gem** - LLM abstraction layer (limited GPT-5 support)
3. **Ground Truth Data** - Expert evaluations in human-readable format

None of these speak the same language, so we had to build translation layers everywhere.

---

## Technology Stack - What We're Actually Using

### Yes, We ARE Using RubyLLM (v1.8.2)

**What RubyLLM Does for Us:**
```ruby
# Line 29 in service.rb
chat = RubyLLM.chat(provider: "openai", model: "gpt-5")
```

RubyLLM is our abstraction layer over the OpenAI API. It handles:
- API authentication (uses OPENAI_API_KEY)
- HTTP requests to OpenAI
- Response parsing
- Model registry (which models are available)

**For GPT-4 ONLY - Structured Output Enforcement:**
```ruby
# Lines 85-94 in service.rb
chat.with_schema(schema)
     .with_temperature(0.1)
     .with_params(max_completion_tokens: 1200)
     .ask(patent_claim_text)
```

This `.with_schema()` method tells OpenAI: "Force the LLM to return EXACTLY this JSON structure."

**For GPT-5 - NO Structured Output Support:**
```ruby
# Lines 43-50 in service.rb
chat.with_params(max_completion_tokens: 1200)
    .with_instructions(system_message)
    .ask(patent_claim_text)
```

Notice: **NO** `.with_schema()` for GPT-5. Why? Because GPT-5 doesn't support it.

### Yes, We ARE Using PromptEngine

**What PromptEngine Does:**
- Stores prompt templates in PostgreSQL database
- Manages prompt versions (like git for prompts)
- Provides UI for editing prompts
- Handles variable substitution ({{patent_id}}, {{claim_text}}, etc.)

**What We Use It For:**
```ruby
# Line 18 in service.rb
rendered = PromptEngine.render(
  "validity-101-agent",
  variables: {
    patent_id: "US10642911B2",
    claim_number: 1,
    claim_text: "A method comprising...",
    abstract: "This patent relates to..."
  }
)
```

PromptEngine gives us back:
- `rendered[:system_message]` - The judge instructions
- `rendered[:content]` - The patent data formatted for the LLM
- `rendered[:model]` - Which model to use (gpt-5)
- `rendered[:temperature]` - How creative the LLM should be (0.1 = very deterministic)

---

## The Ground Truth Transformation Story

### The Problem: Three Different Vocabularies

**Original Ground Truth CSV (from patent experts):**
```csv
Patent Number,Claim #,Alice Step One,Alice Step Two,Overall Eligibility
US6128415A,1,Abstract,No IC Found,Ineligible
US5369702A,1,Not Abstract,N/A,Eligible
```

**What the LLM Returns (via RubyLLM schema for GPT-4):**
```json
{
  "subject_matter": "Abstract",
  "inventive_concept": "No",
  "overall_eligibility": "Ineligible"
}
```

**What the Backend Code Expects (from controller):**
```ruby
# Lines 314-334 in eval_sets_controller.rb
csv_data = {
  "patent_number" => "US6128415A",
  "gt_subject_matter" => "Abstract",
  "gt_inventive_concept" => "No",
  "gt_overall_eligibility" => "Ineligible"
}
```

**THREE DIFFERENT FORMATS FOR THE SAME DATA!**

### Why We Changed The Ground Truth File

**The Decision:** Transform ground truth to match the LLM output format exactly.

**Why This Approach?**
1. **LLM output is constrained by schema** - We can't easily change what GPT returns
2. **Prompt is complex** - Changing it risks breaking the Alice Test logic
3. **Ground truth is static data** - Easiest to transform once upfront

**Alternative Approaches We Rejected:**

**Option A: Transform LLM Output to Match Ground Truth**
```ruby
# We'd need mapping code like:
llm_output["subject_matter"] = "Abstract"
ground_truth_format = transform_to_expert_vocabulary(llm_output)
# Returns: "Alice Step One" => "Abstract", "Alice Step Two" => "No IC Found"
```
❌ **Rejected because:**
- Adds complexity to every evaluation
- Hides what the LLM actually said
- Harder to debug mismatches

**Option B: Transform Both to a Common Format**
```ruby
normalized = {
  step1: normalize_alice_step_one(value),
  step2: normalize_alice_step_two(value),
  eligible: normalize_eligibility(value)
}
```
❌ **Rejected because:**
- More code to maintain
- Two transformation functions instead of one
- Adds another vocabulary to the mix

**Option C: Change the Prompt to Use Ground Truth Vocabulary**
```
System Prompt: "For Alice Step One, return 'Not Abstract' or 'Abstract'"
```
❌ **Rejected because:**
- Prompt is 5000+ characters with complex Alice Test logic
- High risk of breaking legal reasoning
- User said: "WITHOUT CHANGING THE SYSTEM PROMPT"

### The Transformation We Applied

**Conversion Script: `/scripts/convert_ground_truth.rb`**

**Mapping Rules:**
```ruby
# Alice Step One (Expert → LLM Format)
"Abstract"           → "Abstract"              # No change
"Natural Phenomenon" → "Natural Phenomenon"    # No change
"Not Abstract"       → "Not Abstract/Not Natural Phenomenon"  # EXPANDED

# Alice Step Two (Expert → LLM Format)
"No IC Found" → "No"      # SHORTENED
"IC Found"    → "Yes"     # CHANGED
"N/A"         → "-"       # CHANGED

# Overall Eligibility (Expert → LLM Format)
"Eligible"   → "Eligible"     # No change
"Ineligible" → "Ineligible"   # No change
```

**Before Transformation (Original Expert CSV):**
```csv
Patent Number,Claim #,Alice Step One,Alice Step Two,Overall Eligibility
US6128415A,1,Abstract,No IC Found,Ineligible
US5369702A,1,Not Abstract,N/A,Eligible
US10642911B2,1,Abstract,IC Found,Eligible
```

**After Transformation (LLM-Compatible CSV):**
```csv
patent_number,claim_number,gt_subject_matter,gt_inventive_concept,gt_overall_eligibility
US6128415A,1,Abstract,No,Ineligible
US5369702A,1,Not Abstract/Not Natural Phenomenon,-,Eligible
US10642911B2,1,Abstract,Yes,Eligible
```

**Key Changes:**
1. **Column names** changed to match backend expectations (patent_number not "Patent Number")
2. **"Not Abstract"** expanded to **"Not Abstract/Not Natural Phenomenon"** (LLM schema requirement)
3. **"No IC Found"** shortened to **"No"** (LLM returns simple values)
4. **"IC Found"** changed to **"Yes"** (LLM returns Yes/No not IC Found)
5. **"N/A"** changed to **"-"** (LLM uses dash for skipped)

### Real Example: Patent US5369702A

**Original Ground Truth:**
```
Alice Step One: "Not Abstract"
Alice Step Two: "N/A"  (because it's not abstract, we skip step 2)
Overall: "Eligible"
```

**LLM Returns:**
```json
{
  "subject_matter": "Not Abstract/Not Natural Phenomenon",
  "inventive_concept": "-",
  "overall_eligibility": "Eligible"
}
```

**Transformed Ground Truth (for comparison):**
```
gt_subject_matter: "Not Abstract/Not Natural Phenomenon"
gt_inventive_concept: "-"
gt_overall_eligibility: "Eligible"
```

**Now they match! ✅**

**Why "Not Abstract/Not Natural Phenomenon" is so verbose:**
This comes from the LLM schema enum constraint:
```ruby
enum: ["Abstract", "Natural Phenomenon", "Not Abstract/Not Natural Phenomenon"]
```

The LLM must return one of these THREE exact strings. We can't use "Not Abstract" alone because that's ambiguous - it could mean "Natural Phenomenon" (which is also not abstract in a different way).

---

## PromptEngine Integration - Workarounds & Custom Solutions

### What PromptEngine Provides Out-of-Box

According to their documentation, PromptEngine is designed to:
- Store and version prompts
- Test prompts in a "playground" (single execution)
- Run evaluation sets (batch testing)
- Compare expected vs actual outputs
- Show pass/fail metrics

### What We Needed But PromptEngine Doesn't Support

#### 1. **Custom Patent Selection UI** ❌ Not Included

**What PromptEngine Gives You:**
- "Run All Tests" button
- No way to select subset

**What We Needed:**
- Select 5 out of 50 patents for testing
- Avoid spending API tokens on all patents during debugging

**Our Workaround:**
Created custom controller action and view:
```ruby
# app/controllers/prompt_engine/eval_sets_controller.rb
def show
  if params[:mode] == 'run_form'
    # Load our custom patent selection UI
    render 'run_form'
  else
    # Use PromptEngine's default view
    super
  end
end
```

Custom view with checkboxes:
```erb
<!-- app/views/prompt_engine/eval_sets/run_form.html.erb -->
<% @test_cases.each do |test_case| %>
  <label>
    <%= check_box_tag 'selected_patent_ids[]', test_case.input['patent_id'] %>
    <%= test_case.input['patent_id'] %>
  </label>
<% end %>
```

#### 2. **Progress Tracking** ❌ Not Included

**What PromptEngine Gives You:**
- Final results only
- No way to see "15 of 50 complete..."

**Our Workaround:**
Added metadata column to track progress:
```ruby
# Migration: add_metadata_to_prompt_engine_eval_runs.rb
add_column :prompt_engine_eval_runs, :metadata, :jsonb
```

Store progress during evaluation:
```ruby
# app/jobs/evaluation_job.rb
@eval_run.update!(
  metadata: {
    progress: (processed / total * 100).round(2),
    processed: processed,
    total: total,
    selected_patent_ids: ["US123", "US456"]
  }
)
```

Display in UI:
```erb
<!-- app/views/prompt_engine/eval_sets/results.html.erb -->
<% if @eval_run.metadata['progress'] %>
  Progress: <%= @eval_run.metadata['progress'] %>%
<% end %>
```

#### 3. **Ground Truth Comparison View** ❌ Not Included

**What PromptEngine Gives You:**
- Simple "Passed" or "Failed" status
- No detailed field-by-field comparison

**What We Needed:**
- See ground truth vs LLM output side-by-side
- Compare subject_matter, inventive_concept, overall_eligibility separately

**Our Workaround:**
Created entirely custom metrics view:
```erb
<!-- app/views/prompt_engine/eval_sets/metrics.html.erb -->
<table>
  <tr>
    <th>Patent</th>
    <th>Ground Truth: Subject Matter</th>
    <th>LLM Output: Subject Matter</th>
    <th>Ground Truth: Inventive Concept</th>
    <th>LLM Output: Inventive Concept</th>
    <!-- etc -->
  </tr>
</table>
```

#### 4. **Background Job Processing** ❌ Not Included

**What PromptEngine Does:**
- Runs evaluations synchronously
- Browser waits for 50 API calls to complete
- Timeout after 30 seconds

**Our Workaround:**
Created custom background job:
```ruby
# app/jobs/evaluation_job.rb
class EvaluationJob < ApplicationJob
  def perform(eval_set_id, prompt_id, selected_patent_ids)
    # Process patents one by one
    # Update progress after each
    # Run in background worker
  end
end
```

#### 5. **Real-Time LLM Integration** ❌ Partially Supported

**What PromptEngine Expects:**
You to implement a "grader" class that:
1. Takes a test case
2. Generates output somehow
3. Returns output for comparison

**What PromptEngine Doesn't Provide:**
- API integration
- LLM calling
- Response parsing
- Error handling

**Our Implementation:**
```ruby
# app/services/ai/validity_analysis/service.rb
class Service
  def call(patent_number:, claim_number:, claim_text:, abstract:)
    # 1. Format prompt
    # 2. Call OpenAI via RubyLLM
    # 3. Parse JSON response
    # 4. Calculate derived fields
    # 5. Handle errors
    # 6. Return structured result
  end
end
```

Then integrate with PromptEngine's evaluation job:
```ruby
# app/jobs/evaluation_job.rb
result = Ai::ValidityAnalysis::Service.new.call(
  patent_number: test_case['patent_id'],
  claim_number: test_case['claim_number'],
  claim_text: test_case['claim_text'],
  abstract: test_case['abstract']
)

PromptEngine::EvalResult.create!(
  eval_run: @eval_run,
  test_case: test_case,
  output: result.to_json,
  passed: compare_with_ground_truth(result, test_case.expected_output)
)
```

#### 6. **Encrypted API Key Storage** ✅ Included (But Broken)

**What PromptEngine Provides:**
```ruby
# Encrypted storage for API keys
PromptEngine::Setting.create!(
  openai_api_key: ENV['OPENAI_API_KEY']
)
```

**The Problem:**
Encryption config must be loaded BEFORE PromptEngine initializes, but Rails loads environment configs AFTER gems.

**Our Workaround:**
Move encryption config to application.rb:
```ruby
# config/application.rb (loads early)
config.active_record.encryption.primary_key = ENV['ENCRYPTION_PRIMARY_KEY']

# NOT in config/environments/production.rb (loads too late)
```

#### 7. **Validation Score Display** ❌ Not Included

**What PromptEngine Shows:**
- Pass/Fail only
- No detailed scoring

**Our Workaround:**
Created custom "Validity Score" column:
```erb
<td class="validity-score-display">
  <span class="score-value score-<%= score %>">
    <%= score %>/5
  </span>
  <div class="score-bar">
    <div class="score-fill" style="width: <%= score * 20 %>%"></div>
  </div>
</td>
```

With color coding:
- 1-2: Red (poor validity)
- 3: Yellow (moderate)
- 4-5: Green (strong validity)

---

## RubyLLM Integration - The Structured Output Challenge

### What is Structured Output?

**Without Structured Output:**
```
User: "Analyze this patent and return JSON"

LLM: "Based on my analysis, this patent is abstract. Here's the breakdown:
      - Subject Matter: Abstract
      - Inventive Concept: No

      Would you like me to explain further?"
```
❌ Not valid JSON! Includes explanation text.

**With Structured Output (GPT-4):**
```ruby
chat.with_schema({
  type: "object",
  properties: {
    subject_matter: { type: "string", enum: ["Abstract", "Not Abstract"] },
    inventive_concept: { type: "string", enum: ["Yes", "No"] }
  }
})
```

OpenAI API **forces** the response to be:
```json
{
  "subject_matter": "Abstract",
  "inventive_concept": "No"
}
```
✅ Always valid JSON! No extra text.

### GPT-4: RubyLLM `.with_schema()` Works Perfectly

**Our Code:**
```ruby
schema = {
  type: "object",
  properties: {
    subject_matter: {
      type: "string",
      enum: ["Abstract", "Natural Phenomenon", "Not Abstract/Not Natural Phenomenon"]
    },
    inventive_concept: {
      type: "string",
      enum: ["No", "Yes", "-"]
    },
    validity_score: {
      type: "number",
      minimum: 1,
      maximum: 5
    }
  },
  required: ["subject_matter", "inventive_concept", "validity_score"]
}

chat.with_schema(schema).ask("Analyze patent US6128415A...")
```

**What RubyLLM Does Behind The Scenes:**
```ruby
# RubyLLM converts our schema to OpenAI's API format
api_request = {
  model: "gpt-4o",
  messages: [...],
  response_format: {
    type: "json_schema",
    json_schema: {
      name: "patent_analysis",
      strict: true,
      schema: our_schema
    }
  }
}
```

OpenAI enforces the schema and GUARANTEES:
- Response is valid JSON
- Has exactly the fields we specified
- Values match the enum constraints
- Numbers are in the specified range

### GPT-5: `.with_schema()` Doesn't Work At All

**The Problem:**
```ruby
chat.with_schema(schema).ask("Analyze patent...")
# Returns: ""  (empty string!)
```

**Why?**
GPT-5 is a "reasoning model" with different API constraints:
- ❌ Does NOT support `response_format` parameter
- ❌ Does NOT support `json_schema` structured outputs
- ❌ Does NOT support `temperature` parameter
- ❌ Does NOT support many other parameters

From OpenAI documentation:
> "The reasoning models don't support the response_format parameter for structured outputs. Use prompt engineering instead."

### Our Workaround: Prompt-Based JSON Format

**Since we can't use `.with_schema()` for GPT-5, we added to the system prompt:**

```
RESPONSE FORMAT
You must return a JSON object with the following fields:
- patent_number: [The patent number as inputted by the user]
- claim_number: [The claim number evaluated for the patent, as inputted by the user]
- subject_matter: [The output determined for Alice Step One - must be one of: "Abstract", "Natural Phenomenon", "Not Abstract/Not Natural Phenomenon"]
- inventive_concept: [The output determined for Alice Step Two - must be one of: "Yes", "No", "-"]
- validity_score: [The validity score from 1 to 5 determined for the patent claim]

Do not explain your answer, only return the JSON object.
```

**Key Differences:**

| Aspect | GPT-4 with Schema | GPT-5 with Prompt |
|--------|------------------|-------------------|
| **Enforcement** | OpenAI API enforces | LLM follows instructions |
| **Reliability** | 100% valid JSON | ~95% valid JSON |
| **Field Names** | Guaranteed exact | LLM might vary |
| **Enum Values** | Guaranteed from list | LLM might use synonyms |
| **Required Fields** | Enforced by API | LLM might omit |

### How We Handle Both Approaches

**In our service code:**
```ruby
if rendered[:model]&.start_with?('gpt-5')
  # GPT-5: NO schema, rely on prompt
  response = chat
    .with_params(max_completion_tokens: 1200)
    .with_instructions(system_message_with_response_format)
    .ask(patent_text)
else
  # GPT-4: Use strict schema
  response = chat
    .with_schema(schema)
    .with_temperature(0.1)
    .with_params(max_completion_tokens: 1200)
    .with_instructions(system_message)
    .ask(patent_text)
end
```

### Response Type Differences

**GPT-4 via RubyLLM returns:**
```ruby
response.content
# => Hash (already parsed JSON)
# => { "subject_matter" => "Abstract", "inventive_concept" => "No", ... }
```

**GPT-5 via RubyLLM returns:**
```ruby
response.content
# => RubyLLM::Content object
# => #<RubyLLM::Content:0x... @text="{\"subject_matter\":\"Abstract\"}">

response.content.text
# => String (raw JSON text)
# => "{\"subject_matter\":\"Abstract\",\"inventive_concept\":\"No\",...}"
```

**Our Parsing Logic:**
```ruby
content_data = if response.content.is_a?(Hash)
  response.content  # GPT-4: already parsed
elsif response.content.is_a?(String)
  response.content  # Some edge cases
elsif response.content.respond_to?(:text)
  response.content.text  # GPT-5: extract text
else
  raise("Unexpected response type: #{response.content.class}")
end

# Then parse if string
raw = if content_data.is_a?(Hash)
  content_data.with_indifferent_access
else
  JSON.parse(content_data).with_indifferent_access
end
```

---

## GPT-5 vs GPT-4 - Different Approaches Required

### Parameters That Work vs Don't Work

| Parameter | GPT-4 | GPT-5 | Our Solution |
|-----------|-------|-------|--------------|
| `temperature` | ✅ Works | ❌ Not supported | Skip for GPT-5 |
| `max_tokens` | ✅ Works | ❌ Not supported | Use `max_completion_tokens` |
| `response_format: json_schema` | ✅ Works | ❌ Not supported | Use prompt engineering |
| `top_p` | ✅ Works | ❌ Not supported | Don't use |
| `presence_penalty` | ✅ Works | ❌ Not supported | Don't use |
| `frequency_penalty` | ✅ Works | ❌ Not supported | Don't use |

### Conditional Logic Based on Model

**Our Implementation Pattern:**
```ruby
def call(...)
  # Render prompt (same for both models)
  rendered = PromptEngine.render("validity-101-agent", variables: {...})

  # Initialize chat (same for both models)
  chat = RubyLLM.chat(provider: "openai", model: rendered[:model])

  # Different configuration based on model
  if rendered[:model]&.start_with?('gpt-5')
    # === GPT-5 Path ===
    # 1. No schema
    # 2. No temperature
    # 3. Rely on prompt RESPONSE FORMAT section
    # 4. Longer timeout (reasoning takes time)

    response = Timeout.timeout(180) do
      chat.with_params(max_completion_tokens: 1200)
          .with_instructions(system_message)
          .ask(content)
    end
  else
    # === GPT-4 Path ===
    # 1. Strict schema enforcement
    # 2. Temperature control
    # 3. Shorter timeout (faster responses)

    response = Timeout.timeout(180) do
      chat.with_schema(schema)
          .with_temperature(0.1)
          .with_params(max_completion_tokens: 1200)
          .with_instructions(system_message)
          .ask(content)
    end
  end

  # Parse response (different types)
  # Extract data
  # Return result
end
```

### Why GPT-5 Despite The Challenges?

**GPT-5 Advantages:**
- Better reasoning about complex patent law
- More accurate Alice Test application
- Deeper understanding of technical concepts
- More consistent overall eligibility determination

**GPT-4 Advantages:**
- Structured output enforcement
- Faster responses
- More predictable behavior
- Better parameter control

**Our Decision:** Use GPT-5 and work around the limitations because the reasoning quality is worth it.

---

## Key Architecture Decisions

### Decision 1: Transform Ground Truth, Not LLM Output

**Rationale:**
- Ground truth is static CSV (transform once)
- LLM output format is constrained by schema
- Prompt is complex and risky to change
- User requirement: don't change system prompt

**Impact:**
- One-time transformation script
- Ground truth now matches LLM vocabulary exactly
- Comparison is simple string equality

### Decision 2: Automatic Retry with Exponential Backoff

**Problem:**
Patent US10028026B2 would fail on first attempt, succeed on retry.

**Our Solution:**
```ruby
def call(..., retry_count: 0)
  max_retries = 2

  # Try the API call

rescue => e
  if retry_count < max_retries && should_retry?(e)
    wait_time = 2 ** retry_count  # 1s, 2s, 4s
    sleep(wait_time)
    return call(..., retry_count: retry_count + 1)
  end

  # After 3 attempts, give up
end
```

**Why:**
- OpenAI API has intermittent failures
- First request often returns empty string
- Retries almost always succeed
- Exponential backoff prevents API hammering

**Alternative Considered:**
Increase delay between ALL patents (slower, wastes time on successful requests)

### Decision 3: 3-Minute Timeout on API Calls

**Problem:**
Batch evaluation hung for 20+ minutes on patent #3.

**Root Cause:**
Ruby HTTP client has NO default timeout. If OpenAI doesn't respond, we wait forever.

**Our Solution:**
```ruby
response = Timeout.timeout(180) do
  chat.ask(patent_text)
end
```

**Why 3 Minutes:**
- GPT-5 reasoning takes longer than GPT-4
- Patent claims can be 2000+ characters
- Need buffer for API processing
- Combined with retries: 3 attempts × 3 min = 9 min max per patent

**Alternative Considered:**
Shorter timeout (30s) - but GPT-5 legitimately needs more time for complex patents

### Decision 4: Calculate overall_eligibility in Backend

**The Alice Test Logic:**
```
IF subject_matter = "Not Abstract/Not Natural Phenomenon"
  THEN overall_eligibility = "Eligible"
ELSIF inventive_concept = "Yes"
  THEN overall_eligibility = "Eligible"
ELSE
  overall_eligibility = "Ineligible"
```

**We Calculate This in Ruby:**
```ruby
overall_eligibility = if subject_matter == "Not Abstract/Not Natural Phenomenon"
  "Eligible"
elsif inventive_concept == "Yes"
  "Eligible"
else
  "Ineligible"
end
```

**Why Not Ask LLM for overall_eligibility?**
- The logic is deterministic (not fuzzy)
- LLM might make mistakes in simple logic
- We want to DERIVE it from the Alice Test steps
- This is what patent law actually does (Step 1 → Step 2 → Conclusion)

**Alternative Considered:**
Include overall_eligibility in LLM output - but then we're testing if LLM can do basic if/else, not if it understands patent law.

### Decision 5: Store Complete LLM Response

**What We Store:**
```ruby
eval_result.actual_output = {
  subject_matter: "Abstract",
  inventive_concept: "No",
  overall_eligibility: "Ineligible",  # Calculated by us
  validity_score: 2                    # From LLM
}.to_json
```

**Why:**
- Debugging: See exactly what LLM returned
- Analysis: Track how validity_score correlates with eligibility
- History: Original outputs preserved even if we change comparison logic

**Alternative Considered:**
Only store pass/fail boolean - but then we lose visibility into what went wrong.

---

## What We Built From Scratch

### 1. Patent Selection UI
- **Why:** PromptEngine only has "run all" button
- **What:** Checkbox interface for selecting subset of 50 patents
- **Files:** `app/views/prompt_engine/eval_sets/run_form.html.erb`

### 2. Progress Tracking System
- **Why:** PromptEngine shows no progress during evaluation
- **What:** Real-time progress bar showing "15/50 complete"
- **Files:** Migration for metadata column, job that updates progress

### 3. Ground Truth Comparison View
- **Why:** PromptEngine only shows pass/fail
- **What:** Side-by-side field comparison with color coding
- **Files:** `app/views/prompt_engine/eval_sets/metrics.html.erb`

### 4. Background Job Processing
- **Why:** PromptEngine runs synchronously (browser timeout)
- **What:** EvaluationJob that processes in background
- **Files:** `app/jobs/evaluation_job.rb`

### 5. AI Service Integration Layer
- **Why:** PromptEngine doesn't provide LLM integration
- **What:** Complete service that calls OpenAI, parses response, handles errors
- **Files:** `app/services/ai/validity_analysis/service.rb`

### 6. Retry Logic with Exponential Backoff
- **Why:** OpenAI API has intermittent failures
- **What:** Automatic retry up to 2 times with increasing delays
- **Files:** Integrated into service.rb

### 7. Timeout Wrapper
- **Why:** API calls can hang indefinitely
- **What:** 3-minute timeout on all OpenAI requests
- **Files:** Integrated into service.rb

### 8. Ground Truth Transformation Script
- **Why:** Expert vocabulary doesn't match LLM vocabulary
- **What:** One-time script to convert CSV format
- **Files:** `scripts/convert_ground_truth.rb`

### 9. GPT-5 Compatibility Layer
- **Why:** GPT-5 doesn't support same parameters as GPT-4
- **What:** Conditional logic based on model type
- **Files:** service.rb handles both models differently

### 10. Response Type Handling
- **Why:** GPT-4 returns Hash, GPT-5 returns RubyLLM::Content
- **What:** Flexible parsing that handles both
- **Files:** service.rb content extraction logic

### 11. Running Evaluation Banner
- **Why:** No visual feedback that evaluation is in progress
- **What:** Banner with spinner showing "Processing 15/50..."
- **Files:** `app/views/prompt_engine/eval_sets/results.html.erb`

### 12. Validity Score Visualization
- **Why:** PromptEngine doesn't display custom fields
- **What:** Color-coded score display with progress bars
- **Files:** metrics.html.erb with custom CSS

### 13. Error Logging System
- **Why:** Generic errors don't help debugging
- **What:** Detailed error log with patent ID, attempt number, full backtrace
- **Files:** service.rb writes to `log/patent_evaluation_errors.log`

---

## Summary: The Real Architecture

**What We Actually Built:**

```
┌─────────────────────────────────────────────────────────────┐
│                       User Interface                         │
│  (Mix of PromptEngine views + Our custom views)            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Our Custom Controller Layer                     │
│  • Patent selection                                          │
│  • Progress tracking                                         │
│  • Background job triggering                                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              EvaluationJob (Our Code)                       │
│  • Iterate through selected patents                          │
│  • Call AI service for each                                  │
│  • Update progress in real-time                              │
│  • Store results in PromptEngine tables                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│         AI Validity Analysis Service (Our Code)             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 1. Get prompt from PromptEngine                       │  │
│  │ 2. Call OpenAI via RubyLLM                           │  │
│  │ 3. Handle GPT-4 vs GPT-5 differences                 │  │
│  │ 4. Parse JSON response                               │  │
│  │ 5. Calculate overall_eligibility                     │  │
│  │ 6. Retry on failure (up to 2 retries)               │  │
│  │ 7. Timeout after 3 minutes                           │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────┬───────────────────┬────────────────────────────┘
             │                   │
             ▼                   ▼
    ┌────────────────┐  ┌────────────────┐
    │  PromptEngine  │  │   RubyLLM      │
    │  (Database)    │  │   (Gem)        │
    └────────────────┘  └────────┬───────┘
                                 │
                                 ▼
                        ┌────────────────┐
                        │  OpenAI API    │
                        │  (GPT-5)       │
                        └────────────────┘
```

**Key Takeaway:**
We're using PromptEngine and RubyLLM as building blocks, but we built the entire evaluation system, error handling, progress tracking, and UI customization ourselves. Neither gem provides what we need out-of-box for patent evaluation.
