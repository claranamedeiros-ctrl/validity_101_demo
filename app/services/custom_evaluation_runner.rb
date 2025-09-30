# frozen_string_literal: true

# Custom evaluation runner that uses our AI::ValidityAnalysis::Service
# instead of OpenAI Evals API

# Require the AI service explicitly
require Rails.root.join('app', 'services', 'ai', 'validity_analysis', 'service.rb').to_s

class CustomEvaluationRunner
  def initialize(eval_run)
    @eval_run = eval_run
    @eval_set = eval_run.eval_set
    @prompt_version = eval_run.prompt_version
    @prompt = @prompt_version.prompt
    @service = AI::ValidityAnalysis::Service.new
  end

  def execute
    @eval_run.update!(status: :running, started_at: Time.current)

    passed_count = 0
    failed_count = 0
    total_count = @eval_set.test_cases.count

    Rails.logger.info "Starting custom evaluation for #{@eval_set.name} with #{total_count} test cases"

    @eval_set.test_cases.each_with_index do |test_case, index|
      Rails.logger.info "Processing test case #{index + 1}/#{total_count}: #{test_case.description}"

      begin
        # Parse input variables
        input_vars = JSON.parse(test_case.input_variables)

        # Call our service with the test case inputs
        result = @service.call(
          patent_number: input_vars['patent_id'],
          claim_number: input_vars['claim_number'],
          claim_text: input_vars['claim_text'],
          abstract: input_vars['abstract']
        )

        # Check if the service returned an error
        if result[:status] == :error
          Rails.logger.error "Service error for test case #{index + 1}: #{result[:status_message]}"
          failed_count += 1
          create_eval_result(test_case, "ERROR: #{result[:status_message]}", test_case.expected_output, false)
          next
        end

        # Extract the actual result based on our schema
        actual_output = extract_result_for_grading(result)
        expected_output = test_case.expected_output

        # Grade the result based on the eval set's grader type
        passed = grade_result(actual_output, expected_output)

        if passed
          passed_count += 1
          Rails.logger.info "✅ Test case #{index + 1} PASSED"
        else
          failed_count += 1
          Rails.logger.info "❌ Test case #{index + 1} FAILED - Expected: #{expected_output}, Got: #{actual_output}"
        end

        # Create an EvalResult record for detailed tracking
        create_eval_result(test_case, actual_output, expected_output, passed)

      rescue => e
        Rails.logger.error "Error processing test case #{index + 1}: #{e.message}"
        failed_count += 1
        create_eval_result(test_case, "ERROR: #{e.message}", expected_output, false)
      end
    end

    # Update the eval run with final results
    @eval_run.update!(
      status: :completed,
      completed_at: Time.current,
      total_count: total_count,
      passed_count: passed_count,
      failed_count: failed_count
    )

    Rails.logger.info "Evaluation completed: #{passed_count}/#{total_count} passed (#{((passed_count.to_f / total_count) * 100).round(1)}%)"

  rescue => e
    Rails.logger.error "Evaluation failed: #{e.message}"
    @eval_run.update!(
      status: :failed,
      error_message: e.message,
      completed_at: Time.current
    )
    raise
  end

  private

  def extract_result_for_grading(service_result)
    # Extract the field we're testing based on the grader type
    # For "contains" grader, we're looking for overall eligibility
    # service_result is a Hash with keys: status, patent_number, subject_matter, inventive_concept, validity_score, overall_eligibility
    case @eval_set.grader_type
    when 'contains'
      # Return the overall eligibility result (it's already a string like "eligible" or "ineligible")
      service_result[:overall_eligibility] || service_result['overall_eligibility']
    when 'exact_match'
      # For exact match, return the full relevant data as JSON
      {
        subject_matter: service_result[:subject_matter] || service_result['subject_matter'],
        inventive_concept: service_result[:inventive_concept] || service_result['inventive_concept'],
        overall_eligibility: service_result[:overall_eligibility] || service_result['overall_eligibility']
      }.to_json
    else
      # Default to overall eligibility
      service_result[:overall_eligibility] || service_result['overall_eligibility']
    end
  end

  def grade_result(actual_output, expected_output)
    case @eval_set.grader_type
    when 'exact_match'
      actual_output == expected_output
    when 'contains'
      actual_output.to_s.include?(expected_output.to_s)
    when 'regex'
      pattern = @eval_set.grader_config['pattern']
      return false if pattern.blank?
      Regexp.new(pattern).match?(actual_output.to_s)
    when 'json_schema'
      # For JSON schema, we'd need more complex validation
      # For now, just do exact match on the JSON
      actual_output == expected_output
    else
      # Default to exact match
      actual_output == expected_output
    end
  end

  def create_eval_result(test_case, actual_output, expected_output, passed)
    # Check if EvalResult model exists in PromptEngine
    if defined?(PromptEngine::EvalResult)
      PromptEngine::EvalResult.create!(
        eval_run: @eval_run,
        test_case: test_case,
        output: actual_output.to_s,
        expected_output: expected_output.to_s,
        passed: passed
      )
    end
  rescue => e
    Rails.logger.warn "Could not create EvalResult record: #{e.message}"
  end
end