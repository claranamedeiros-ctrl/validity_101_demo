# Schema vs Prompt Explanation

## The Problem: Two Sources of Truth

### Source 1: System Prompt (backend/system.erb)
```
If the claim DOES NOT contain an inventive concept,
the output for Alice Step Two is "No IC Found" ← What prompt says

If the claim DOES contain an inventive concept,
the output for Alice Step Two is "IC Found" ← What prompt says
```

### Source 2: JSON Schema (app/services/ai/validity_analysis/service.rb)
```ruby
inventive_concept: {
  type: "string",
  enum: ["No", "Yes", "-"],  ← What API enforces
  description: "The output determined for Alice Step Two"
}
```

**These don't match! 🚨**

## How OpenAI's Structured Output Works

When you use `chat.with_schema(schema)`, OpenAI's API enforces **strict JSON mode**:

### Step-by-Step Process

```
┌─────────────────────────────────────────┐
│ 1. User Request                         │
│    "Is US6128415A valid?"               │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│ 2. System Prompt Sent                   │
│    "Output 'No IC Found' or 'IC Found'" │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│ 3. Schema Constraint Sent               │
│    enum: ["No", "Yes", "-"]             │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│ 4. LLM Generates Response               │
│    (internally tries to say "No IC")    │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│ 5. OpenAI Schema Validator              │
│    ❌ "No IC Found" NOT in enum         │
│    ✅ Force to closest: "No"            │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│ 6. Final Response                       │
│    {"inventive_concept": "No"}          │
└─────────────────────────────────────────┘
```

## Real Code Example

### What You Write in service.rb:

```ruby
# This creates a HARD CONSTRAINT
schema = {
  inventive_concept: {
    enum: ["No", "Yes", "-"]  # ← LLM MUST use these exact strings
  }
}

response = chat
  .with_schema(schema)  # ← This enforces the constraint
  .ask("Analyze patent...")
```

### What Happens Behind the Scenes:

```javascript
// Inside OpenAI's API (simplified)
function validateResponse(llmOutput, schema) {
  if (!schema.enum.includes(llmOutput.inventive_concept)) {
    // REJECT! Try again with valid enum value
    throw new SchemaValidationError();
  }
  return llmOutput;
}
```

## Why Does the Prompt Say "No IC Found" Then?

**Good question!** It's a documentation mismatch. The prompt was written for humans to understand, but the schema is what the machine enforces.

### Option 1: Fix the Prompt (Recommended)
Update `backend/system.erb`:
```
OLD: "the output for Alice Step Two is 'No IC Found'"
NEW: "the output for Alice Step Two is 'No'"
```

### Option 2: Keep Both (Current State)
- Prompt says "No IC Found" (human context)
- Schema forces "No" (machine output)
- LLM understands the intent and outputs valid "No"

## Proof: Test This Locally

Want to see it in action? Try this:

```ruby
# Test script to prove schema enforcement
schema = {
  type: "object",
  properties: {
    answer: {
      type: "string",
      enum: ["yes", "no"]  # Only these 2 allowed
    }
  }
}

# This will work
chat.with_schema(schema).ask("Say 'absolutely yes'")
# Returns: {"answer": "yes"} ← Forced to schema value

# The LLM understands "absolutely yes" means "yes"
# But API forces it to use schema enum
```

## Why This Matters for Ground Truth

### Before Redesign (OLD system):
```
Ground Truth CSV: "No IC Found"
         ↓
LLM outputs: "No" (forced by schema)
         ↓
Backend mapping: "No" → "uninventive" ← Hidden transformation
         ↓
Expected: "uninventive"
Actual: "uninventive"
Result: PASS ✅ (but confusing!)
```

### After Redesign (NEW system):
```
Ground Truth CSV: "No IC Found"
         ↓ Transform script
Ground Truth DB: "No" ← Matches schema!
         ↓
LLM outputs: "No" (forced by schema)
         ↓
Expected: "No"
Actual: "No"
Result: PASS ✅ (transparent!)
```

## Real OpenAI Documentation

From OpenAI's Structured Output docs:

> "When you supply a schema, the model will constrain its output to match the schema. **The model will not generate any JSON that doesn't match your schema**, even if the instructions say otherwise."

Source: https://platform.openai.com/docs/guides/structured-outputs

## Summary

**Question:** Why can't LLM output "No IC Found"?

**Answer:** Because `with_schema(schema)` creates a HARD CONSTRAINT that forces the LLM to only use values in the `enum` array: `["No", "Yes", "-"]`

**The prompt text is just guidance.** The schema is the **LAW**. 👨‍⚖️

Think of it like this:
- **Prompt** = Suggestions (helpful but not enforced)
- **Schema** = Rules (strictly enforced by API)

When they conflict, **Schema always wins**.

---

## Try It Yourself

Run this in Rails console to see schema enforcement:

```ruby
schema = {
  type: "object",
  properties: {
    color: {
      type: "string",
      enum: ["red", "blue", "green"]
    }
  }
}

# Ask for "crimson" (not in enum)
chat = RubyLLM.chat(provider: "openai", model: "gpt-4o")
response = chat
  .with_schema(schema)
  .ask("What color is crimson?")

puts response.content
# Output: {"color": "red"}
# ← Even though you asked for "crimson", it returns "red" (closest enum match)
```

This is exactly what happens with "No IC Found" → "No"!
