# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_25_141316) do
  create_table "prompt_engine_eval_results", force: :cascade do |t|
    t.integer "eval_run_id", null: false
    t.integer "test_case_id", null: false
    t.text "actual_output"
    t.integer "passed", default: 0
    t.integer "execution_time_ms"
    t.text "error_message"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "prompt_engine_eval_runs", force: :cascade do |t|
    t.integer "eval_set_id", null: false
    t.integer "prompt_version_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "started_at", precision: nil
    t.datetime "completed_at", precision: nil
    t.integer "total_count", default: 0
    t.integer "passed_count", default: 0
    t.integer "failed_count", default: 0
    t.text "error_message"
    t.text "openai_run_id"
    t.text "openai_file_id"
    t.text "report_url"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.json "metadata", default: {}
    t.index ["openai_run_id"], name: "index_prompt_engine_eval_runs_on_openai_run_id"
  end

  create_table "prompt_engine_eval_sets", force: :cascade do |t|
    t.text "name", null: false
    t.text "description"
    t.integer "prompt_id", null: false
    t.text "openai_eval_id"
    t.text "grader_type", default: "exact_match", null: false
    t.text "grader_config", default: "{}"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["grader_type"], name: "index_prompt_engine_eval_sets_on_grader_type"
    t.index ["openai_eval_id"], name: "index_prompt_engine_eval_sets_on_openai_eval_id"
    t.index ["prompt_id", "name"], name: "index_prompt_engine_eval_sets_on_prompt_id_and_name", unique: true
  end

  create_table "prompt_engine_parameters", force: :cascade do |t|
    t.integer "prompt_id", null: false
    t.text "name", null: false
    t.text "description"
    t.text "parameter_type", default: "string", null: false
    t.integer "required", default: 1, null: false
    t.text "default_value"
    t.text "validation_rules"
    t.text "example_value"
    t.integer "position"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["position"], name: "index_prompt_engine_parameters_on_position"
    t.index ["prompt_id", "name"], name: "index_prompt_engine_parameters_on_prompt_id_and_name", unique: true
  end

# Could not dump table "prompt_engine_playground_run_results" because of following StandardError
#   Unknown type 'REAL' for column 'execution_time'


# Could not dump table "prompt_engine_prompt_versions" because of following StandardError
#   Unknown type 'REAL' for column 'temperature'


# Could not dump table "prompt_engine_prompts" because of following StandardError
#   Unknown type 'REAL' for column 'temperature'


  create_table "prompt_engine_settings", force: :cascade do |t|
    t.text "openai_api_key"
    t.text "anthropic_api_key"
    t.text "preferences", default: "{}"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "prompt_engine_test_cases", force: :cascade do |t|
    t.integer "eval_set_id", null: false
    t.text "input_variables", default: "{}", null: false
    t.text "expected_output", null: false
    t.text "description"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  add_foreign_key "prompt_engine_eval_results", "prompt_engine_eval_runs", column: "eval_run_id"
  add_foreign_key "prompt_engine_eval_results", "prompt_engine_test_cases", column: "test_case_id"
  add_foreign_key "prompt_engine_eval_runs", "prompt_engine_eval_sets", column: "eval_set_id"
  add_foreign_key "prompt_engine_eval_runs", "prompt_engine_prompt_versions", column: "prompt_version_id"
  add_foreign_key "prompt_engine_eval_sets", "prompt_engine_prompts", column: "prompt_id"
  add_foreign_key "prompt_engine_parameters", "prompt_engine_prompts", column: "prompt_id"
  add_foreign_key "prompt_engine_playground_run_results", "prompt_engine_prompt_versions", column: "prompt_version_id"
  add_foreign_key "prompt_engine_prompt_versions", "prompt_engine_prompts", column: "prompt_id"
  add_foreign_key "prompt_engine_test_cases", "prompt_engine_eval_sets", column: "eval_set_id"
end
