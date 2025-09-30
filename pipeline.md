# Patent Validity Evaluation Pipeline Documentation

## Overview

This document explains the complete data transformation pipeline used in our Patent Validity Evaluation System, built on top of the PromptEngine gem. The system evaluates patent claims using the Alice Test methodology for determining patent eligibility.

## 🔄 Data Flow Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌──────────────────┐
│  Ground Truth   │    │  Transformation  │    │   LLM Schema    │    │   Evaluation     │
│     Data        │────▶│     Rules        │────▶│   (RubyLLM)     │────▶│   & Results     │
│   (CSV File)    │    │  (Custom Logic)  │    │   (Structured)  │    │   (Comparison)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘    └──────────────────┘
```

### Step-by-Step Pipeline Flow

1. **Ground Truth Loading** → 2. **Transformation Rules** → 3. **LLM Analysis** → 4. **Results Comparison** → 5. **Metrics Display**

---

## 📊 Ground Truth Data Structure

### Original CSV Format (`/groundt/gt_aligned_normalized_test.csv`)

The ground truth file contains 50 patents with the following columns:

```csv
patent_number,claim_number,gt_subject_matter,gt_inventive_concept,gt_overall_eligibility
US6128415A,1,abstract,no ic found,ineligible
US7818399B1,1,abstract,ic found,eligible
US5768416A,1,patentable,nan,eligible
```

### Original Values in Ground Truth

#### Subject Matter Column (`gt_subject_matter`)
- **`abstract`** - Abstract ideas (typically ineligible)
- **`patentable`** - Patentable subject matter (typically eligible)

#### Inventive Concept Column (`gt_inventive_concept`)
- **`no ic found`** - No Inventive Concept Found
- **`ic found`** - Inventive Concept Found
- **`nan`** - Not Available/Not Applicable (missing data)

#### Overall Eligibility Column (`gt_overall_eligibility`)
- **`eligible`** - Patent claim is eligible
- **`ineligible`** - Patent claim is ineligible

---

## 🔄 Transformation Rules Engine

### When Transformations Occur

Transformations happen in **real-time during results display** in the `load_ground_truth_data` method of `/app/controllers/prompt_engine/eval_sets_controller.rb` (lines 318-327).

### Subject Matter Transformations

**NO TRANSFORMATIONS APPLIED** - Subject matter values are passed through unchanged:
- `abstract` → `abstract` (unchanged)
- `patentable` → `patentable` (unchanged)

### Inventive Concept Transformations

**Active transformation rules** applied to match LLM schema enums:

```ruby
mapped_inventive_concept = case row['gt_inventive_concept']&.downcase
when 'no ic found', 'none', 'no inventive concept'
  'uninventive'
when 'inventive concept found', 'yes', 'inventive'
  'inventive'
when 'skipped', 'skip'
  'skipped'
else
  row['gt_inventive_concept'] # Keep original if it already matches
end
```

#### Transformation Mapping Table

| Ground Truth Original | Transformation Rule | LLM Schema Output |
|----------------------|---------------------|-------------------|
| `"no ic found"` | Mapped to | `"uninventive"` |
| `"ic found"` | Mapped to | `"inventive"` |
| `"nan"` | Passed through | `"nan"` (no mapping) |

### Why Transformations Are Needed

The transformation layer exists because:

1. **Ground Truth Uses Human-Readable Labels**: `"no ic found"` vs `"ic found"`
2. **LLM Schema Uses Standardized Enums**: `"uninventive"` vs `"inventive"`
3. **Comparison Requires Matching Vocabularies**: Both sides must use same terminology

---

## 🤖 LLM Schema Definition

### RubyLLM Schema Structure (`/app/services/ai/validity_analysis/schema.rb`)

```ruby
module AI::ValidityAnalysis
  class Schema < RubyLLM::Schema
    string :patent_number, description: 'The patent number as inputted by the user'
    number :claim_number, description: 'The claim number evaluated for the patent'
    string :subject_matter, enum: %w[abstract natural_phenomenon patentable],
                            description: 'The subject matter of the claim'
    string :inventive_concept, enum: %w[inventive uninventive skipped],
                               description: 'The inventive concept of the claim'
    number :validity_score, minimum: 1, maximum: 5,
                           description: 'Score from 1 to 5 with the validity strength'
  end
end
```

### LLM Output Example

```json
{
  "patent_number": "US7818399B1",
  "claim_number": 1,
  "subject_matter": "abstract",
  "inventive_concept": "uninventive",
  "validity_score": 2,
  "overall_eligibility": "ineligible"
}
```

---

## ⚖️ Evaluation & Comparison Logic

### Grading Process (`/app/jobs/evaluation_job.rb`)

1. **Extract Result for Grading** (lines 140-155):
   ```ruby
   # For 'exact_match' grader type:
   eligibility = service_result[:overall_eligibility] || service_result['overall_eligibility']
   eligibility.to_s
   ```

2. **Grade Result** (lines 157-181):
   ```ruby
   case @eval_set.grader_type
   when 'exact_match'
     actual_normalized == expected_normalized
   when 'contains'
     actual_normalized.include?(expected_normalized)
   end
   ```

3. **Comparison Example**:
   - **Ground Truth**: `"no ic found"` → (transformed to) → `"uninventive"`
   - **LLM Output**: `"uninventive"`
   - **Result**: ✅ MATCH (Test PASSED)

---

## 🛠️ Custom Code vs Native PromptEngine

### What's Native PromptEngine Functionality

The PromptEngine gem provides:
- ✅ Basic prompt management and versioning
- ✅ Test case creation and storage
- ✅ Evaluation run tracking
- ✅ Simple grading logic (`exact_match`, `contains`, `regex`)
- ✅ Basic UI for managing prompts and evaluations

### What We Had to Build Custom

#### 1. **Custom Evaluation Runner** (`/app/jobs/evaluation_job.rb`)
**Why**: PromptEngine uses OpenAI Evals API, but we needed:
- Custom AI service integration (RubyLLM + GPT-4o)
- Patent-specific data processing
- Alice Test methodology implementation
- Background job processing for long-running evaluations

#### 2. **Patent Selection Interface** (`/app/views/prompt_engine/eval_sets/run_form.html.erb`)
**Why**: PromptEngine runs all test cases automatically, but we needed:
- Selective patent testing (to save tokens during development)
- Checkbox interface for choosing specific patents
- Custom UI for patent selection workflow

#### 3. **Ground Truth Transformation Engine** (`/app/controllers/prompt_engine/eval_sets_controller.rb`)
**Why**: PromptEngine compares raw values, but we needed:
- Translation between human-readable labels and LLM schema enums
- Flexible mapping rules for different data formats
- Support for legacy ground truth data

#### 4. **Enhanced Results Display**
**Custom Views Created**:
- `/app/views/prompt_engine/dashboard/index.html.erb` - Enhanced dashboard
- `/app/views/prompt_engine/eval_runs/show.html.erb` - Fixed patent count display
- `/app/views/prompt_engine/eval_sets/metrics.html.erb` - Real LLM data display
- `/app/views/prompt_engine/eval_sets/results.html.erb` - Ground truth comparison
- `/app/views/prompt_engine/evaluations/index.html.erb` - Fixed View links

**Why**: PromptEngine provides basic result views, but we needed:
- Ground truth vs LLM comparison matrices
- Patent-specific result filtering
- Alice Test methodology-specific metrics
- Integration with our custom evaluation pipeline

#### 5. **Custom Controller Overrides** (`/app/controllers/prompt_engine/eval_sets_controller.rb`)
**Why**: PromptEngine controllers are basic, but we needed:
- Mode-based routing (`?mode=run_form`, `?mode=results`)
- Patent selection parameter handling
- Ground truth data loading and transformation
- Custom evaluation job triggering

### Workarounds We Had to Implement

#### 1. **View Override Strategy**
**Problem**: PromptEngine gem views couldn't be easily customized
**Solution**: Created local view overrides in `/app/views/prompt_engine/` that automatically take precedence over gem views

#### 2. **Controller Extension Pattern**
**Problem**: PromptEngine controllers needed additional functionality
**Solution**: Used `require_dependency` to override gem controllers while maintaining original functionality

#### 3. **Background Job Integration**
**Problem**: PromptEngine evaluation is synchronous and limited to OpenAI Evals
**Solution**: Created custom `EvaluationJob` using ActiveJob for asynchronous processing with our AI service

#### 4. **Metadata Storage Workaround**
**Problem**: PromptEngine eval_runs table doesn't store custom evaluation metadata
**Solution**: Used existing `metadata` JSON column to store `selected_patent_ids` and progress tracking

---

## 🔍 Real-World Scenarios

### Scenario 1: Patent US7818399B1 Evaluation

#### Input Data Flow:
```
1. Ground Truth: "ic found"
   ↓ [Transformation Rule]
2. Expected: "inventive"
   ↓ [LLM Analysis]
3. LLM Output: "uninventive"
   ↓ [Comparison: exact_match]
4. Result: ❌ FAILED ("inventive" ≠ "uninventive")
```

### Scenario 2: Patent US6128415A Evaluation

#### Input Data Flow:
```
1. Ground Truth: "no ic found"
   ↓ [Transformation Rule]
2. Expected: "uninventive"
   ↓ [LLM Analysis]
3. LLM Output: "uninventive"
   ↓ [Comparison: exact_match]
4. Result: ✅ PASSED ("uninventive" = "uninventive")
```

### Scenario 3: Missing Data Handling

#### Input Data Flow:
```
1. Ground Truth: "nan" (Not Available)
   ↓ [Transformation Rule]
2. Expected: "nan" (No mapping rule, passed through)
   ↓ [LLM Analysis]
3. LLM Output: "skipped"
   ↓ [Comparison: exact_match]
4. Result: ❌ FAILED ("nan" ≠ "skipped")
```

---

## 🎯 Key Pipeline Locations

### Files and Line Numbers

| Component | File Location | Key Lines |
|-----------|---------------|-----------|
| **Ground Truth Loading** | `/app/controllers/prompt_engine/eval_sets_controller.rb` | 308-341 |
| **Transformation Rules** | `/app/controllers/prompt_engine/eval_sets_controller.rb` | 318-327 |
| **LLM Schema Definition** | `/app/services/ai/validity_analysis/schema.rb` | 8-11 |
| **Evaluation Logic** | `/app/jobs/evaluation_job.rb` | 140-181 |
| **Results Comparison** | `/app/controllers/prompt_engine/eval_sets_controller.rb` | 382-399 |

### Custom vs Native Mapping

| Functionality | Native PromptEngine | Our Custom Implementation |
|---------------|-------------------|-------------------------|
| **Evaluation Engine** | OpenAI Evals API | `EvaluationJob` + RubyLLM |
| **Patent Selection** | All tests automatically | `run_form.html.erb` + checkboxes |
| **Data Transformation** | Raw value comparison | `mapped_inventive_concept` rules |
| **Results Display** | Basic pass/fail | Ground truth comparison matrix |
| **UI Navigation** | Standard gem views | Enhanced with custom overrides |

---

## 📈 Performance & Scalability Notes

- **Background Processing**: EvaluationJob runs asynchronously to handle long-running AI analysis
- **Token Optimization**: Patent selection interface allows subset testing to reduce API costs
- **Progress Tracking**: Real-time progress updates via metadata column in eval_runs
- **Error Handling**: Comprehensive error catching and logging throughout evaluation pipeline

---

## 🔧 Future Enhancement Opportunities

1. **Dynamic Transformation Rules**: Move hardcoded rules to database configuration
2. **Additional Grader Types**: Implement fuzzy matching and semantic similarity
3. **Batch Processing**: Optimize AI service calls for multiple patents
4. **Real-time Updates**: WebSocket integration for live progress tracking
5. **Export Functionality**: CSV/PDF export of detailed comparison results

---

*Last Updated: September 29, 2025*
*System Status: Fully Operational with Fixed Grader Logic*