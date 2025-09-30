-- Complete PromptEngine Database Schema - Production Ready

-- Create the main prompts table
CREATE TABLE prompt_engine_prompts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    description TEXT,
    content TEXT,
    system_message TEXT,
    model TEXT,
    temperature REAL,
    max_tokens INTEGER,
    status TEXT,
    metadata TEXT,
    versions_count INTEGER DEFAULT 0 NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL
);

-- Create prompt versions table
CREATE TABLE prompt_engine_prompt_versions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    prompt_id INTEGER NOT NULL,
    version_number INTEGER NOT NULL,
    content TEXT NOT NULL,
    system_message TEXT,
    model TEXT,
    temperature REAL,
    max_tokens INTEGER,
    metadata TEXT,
    created_by TEXT,
    change_description TEXT,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    FOREIGN KEY (prompt_id) REFERENCES prompt_engine_prompts (id)
);

-- Create parameters table
CREATE TABLE prompt_engine_parameters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    prompt_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    parameter_type TEXT DEFAULT 'string' NOT NULL,
    required INTEGER DEFAULT 1 NOT NULL,
    default_value TEXT,
    validation_rules TEXT,
    example_value TEXT,
    position INTEGER,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    FOREIGN KEY (prompt_id) REFERENCES prompt_engine_prompts (id)
);

-- Create eval sets table
CREATE TABLE prompt_engine_eval_sets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    prompt_id INTEGER NOT NULL,
    openai_eval_id TEXT,
    grader_type TEXT DEFAULT 'exact_match' NOT NULL,
    grader_config TEXT DEFAULT '{}',
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    FOREIGN KEY (prompt_id) REFERENCES prompt_engine_prompts (id)
);

-- Create test cases table
CREATE TABLE prompt_engine_test_cases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    eval_set_id INTEGER NOT NULL,
    input_variables TEXT DEFAULT '{}' NOT NULL,
    expected_output TEXT NOT NULL,
    description TEXT,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    FOREIGN KEY (eval_set_id) REFERENCES prompt_engine_eval_sets (id)
);

-- Create eval runs table
CREATE TABLE prompt_engine_eval_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    eval_set_id INTEGER NOT NULL,
    prompt_version_id INTEGER NOT NULL,
    status INTEGER DEFAULT 0 NOT NULL,
    started_at DATETIME,
    completed_at DATETIME,
    total_count INTEGER DEFAULT 0,
    passed_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    error_message TEXT,
    openai_run_id TEXT,
    openai_file_id TEXT,
    report_url TEXT,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    FOREIGN KEY (eval_set_id) REFERENCES prompt_engine_eval_sets (id),
    FOREIGN KEY (prompt_version_id) REFERENCES prompt_engine_prompt_versions (id)
);

-- Create eval results table
CREATE TABLE prompt_engine_eval_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    eval_run_id INTEGER NOT NULL,
    test_case_id INTEGER NOT NULL,
    actual_output TEXT,
    passed INTEGER DEFAULT 0,
    execution_time_ms INTEGER,
    error_message TEXT,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    FOREIGN KEY (eval_run_id) REFERENCES prompt_engine_eval_runs (id),
    FOREIGN KEY (test_case_id) REFERENCES prompt_engine_test_cases (id)
);

-- Create playground run results table
CREATE TABLE prompt_engine_playground_run_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    prompt_version_id INTEGER NOT NULL,
    provider TEXT NOT NULL,
    model TEXT NOT NULL,
    rendered_prompt TEXT NOT NULL,
    system_message TEXT,
    parameters TEXT,
    response TEXT NOT NULL,
    execution_time REAL NOT NULL,
    token_count INTEGER,
    temperature REAL,
    max_tokens INTEGER,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    FOREIGN KEY (prompt_version_id) REFERENCES prompt_engine_prompt_versions (id)
);

-- Create settings table
CREATE TABLE prompt_engine_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    openai_api_key TEXT,
    anthropic_api_key TEXT,
    preferences TEXT DEFAULT '{}',
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL
);

-- Performance indexes
CREATE UNIQUE INDEX index_prompt_versions_on_prompt_and_version ON prompt_engine_prompt_versions (prompt_id, version_number);
CREATE INDEX index_prompt_engine_prompt_versions_on_version_number ON prompt_engine_prompt_versions (version_number);
CREATE UNIQUE INDEX index_prompt_engine_parameters_on_prompt_id_and_name ON prompt_engine_parameters (prompt_id, name);
CREATE INDEX index_prompt_engine_parameters_on_position ON prompt_engine_parameters (position);
CREATE UNIQUE INDEX index_prompt_engine_eval_sets_on_prompt_id_and_name ON prompt_engine_eval_sets (prompt_id, name);
CREATE INDEX index_prompt_engine_eval_sets_on_openai_eval_id ON prompt_engine_eval_sets (openai_eval_id);
CREATE INDEX index_prompt_engine_eval_sets_on_grader_type ON prompt_engine_eval_sets (grader_type);
CREATE INDEX index_prompt_engine_eval_runs_on_openai_run_id ON prompt_engine_eval_runs (openai_run_id);
CREATE INDEX index_prompt_engine_playground_run_results_on_provider ON prompt_engine_playground_run_results (provider);
CREATE INDEX index_prompt_engine_playground_run_results_on_created_at ON prompt_engine_playground_run_results (created_at);