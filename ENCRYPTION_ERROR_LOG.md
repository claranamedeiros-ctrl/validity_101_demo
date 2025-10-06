# Encryption Error - Troubleshooting Log

## Error Details

**URL:** https://validity101demo-production.up.railway.app/prompt_engine/prompts/1/eval_sets/2

**Error:**
```
ActiveRecord::Encryption::Errors::Configuration in PromptEngine::EvalSets#show

Missing Active Record encryption credential: active_record_encryption.primary_key

Location: /usr/local/rvm/gems/ruby-3.4.5/gems/prompt_engine-1.0.0/app/views/prompt_engine/eval_sets/show.html.erb line #22

Code triggering error (line 302):
settings = PromptEngine::Setting.instance
settings.openai_configured?
```

**Parameters:** `{"prompt_id" => "1", "id" => "2"}`

---

## Root Cause

The error is NOT in our app code. It's in the **PromptEngine gem** when it tries to access `PromptEngine::Setting.instance`.

The PromptEngine gem has an encrypted model (`Setting`) that stores API keys, and it's trying to decrypt data BEFORE our Rails config loads.

---

## Failed Attempts

### Attempt 1: Set encryption key manually
**Action:** Added `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` to Railway variables
**Result:** ❌ FAILED - Variable not accessible or didn't trigger redeploy

### Attempt 2: Change ENV.fetch to ENV[]
**Action:** Modified config/environments/production.rb to use `ENV[] || fallback`
**Result:** ❌ FAILED - Gem loads before config executes

---

## Real Problem

The PromptEngine gem is trying to decrypt the `Setting` record BEFORE our production.rb config runs. This means:

1. Gem initializes → tries to load Setting model → needs encryption keys
2. Rails config loads → sets encryption keys
3. **TOO LATE!** Gem already failed.

---

## Real Solution Options

### Option 1: Set encryption keys in credentials.yml.enc (CORRECT WAY)
The PromptEngine gem expects encryption keys in Rails credentials, not ENV vars.

**How to fix:**
```bash
# Edit credentials
EDITOR="nano" rails credentials:edit --environment production

# Add these lines:
active_record_encryption:
  primary_key: d861320c1482a2b1228b17b074281606ee0a7007f83cc4d11abb26dccee801c5
  deterministic_key: [another key]
  key_derivation_salt: [another key]
```

**Problem:** Can't edit production credentials without RAILS_MASTER_KEY on Railway

### Option 2: Initialize encryption in config/application.rb (EARLIER)
Move encryption setup to application.rb so it loads BEFORE gems initialize.

### Option 3: Create PromptEngine::Setting record without encryption
Initialize the Setting record in a way that doesn't require decryption.

### Option 4: Patch the PromptEngine gem controller
Override the problematic method to not check settings.

---

## Investigation Needed

1. Check if Setting record exists in database
2. Check if we actually need the Setting record
3. Check if we can bypass this check

---

**Status:** BLOCKED on encryption initialization order
**Next Step:** Try Option 2 (move config to application.rb)
