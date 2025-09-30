# frozen_string_literal: true

# Load service dependencies at class level
begin
  require Rails.root.join('app/services/ai/validity_analysis/overall_eligibility')
  require Rails.root.join('app/services/ai/validity_analysis/validity_score')
  require Rails.root.join('app/services/ai/validity_analysis/service')
rescue LoadError
  # Fallback for development/test environments
end

class EvaluationJob < ApplicationJob
  queue_as :default

  def perform(eval_run_id, selected_patent_ids = nil)
    @eval_run = PromptEngine::EvalRun.find(eval_run_id)
    @eval_set = @eval_run.eval_set
    @prompt_version = @eval_run.prompt_version
    @prompt = @prompt_version.prompt

    # Create service instance
    @service = AI::ValidityAnalysis::Service.new

    @eval_run.update!(status: :running, started_at: Time.current)

    passed_count = 0
    failed_count = 0
    processed_count = 0

    # Filter test cases if specific patent IDs are selected
    test_cases = if selected_patent_ids
      @eval_set.test_cases.select do |tc|
        input_vars = JSON.parse(tc.input_variables)
        selected_patent_ids.include?(input_vars['patent_id'])
      end
    else
      @eval_set.test_cases.to_a
    end

    total_count = test_cases.count

    Rails.logger.info "Starting custom evaluation for #{@eval_set.name} with #{total_count} test cases"

    test_cases.each_with_index do |test_case, index|
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
        else
          # Extract the actual result based on our schema for grading
          actual_output_for_grading = extract_result_for_grading(result)
          expected_output = test_case.expected_output

          # Grade the result based on the eval set's grader type
          passed = grade_result(actual_output_for_grading, expected_output)

          if passed
            passed_count += 1
            Rails.logger.info "✅ Test case #{index + 1} PASSED"
          else
            failed_count += 1
            Rails.logger.info "❌ Test case #{index + 1} FAILED - Expected: #{expected_output}, Got: #{actual_output_for_grading}"
          end

          # Store the complete result data as JSON for UI display
          complete_result = {
            subject_matter: result[:subject_matter] || result['subject_matter'],
            inventive_concept: result[:inventive_concept] || result['inventive_concept'],
            overall_eligibility: result[:overall_eligibility] || result['overall_eligibility'],
            validity_score: result[:validity_score] || result['validity_score']
          }.to_json

          # Create an EvalResult record for detailed tracking
          create_eval_result(test_case, complete_result, expected_output, passed)
        end

        processed_count += 1

        # Update progress in eval_run metadata
        progress = (processed_count.to_f / total_count * 100).round(2)
        @eval_run.update!(
          metadata: (@eval_run.metadata || {}).merge({
            progress: progress,
            processed: processed_count,
            total: total_count,
            selected_patent_ids: selected_patent_ids
          }.compact)
        )

      rescue => e
        Rails.logger.error "Error processing test case #{index + 1}: #{e.message}"
        failed_count += 1
        create_eval_result(test_case, "ERROR: #{e.message}", test_case.expected_output, false)
        processed_count += 1
      end
    end

    # Update the eval run with final results
    @eval_run.update!(
      status: :completed,
      completed_at: Time.current,
      total_count: total_count,
      passed_count: passed_count,
      failed_count: failed_count,
      metadata: (@eval_run.metadata || {}).merge({
        progress: 100,
        processed: processed_count,
        total: total_count
      })
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
    case @eval_set.grader_type
    when 'contains'
      # Extract just the overall_eligibility value as a string
      eligibility = service_result[:overall_eligibility] || service_result['overall_eligibility']
      eligibility.to_s
    when 'exact_match'
      # Extract just the overall_eligibility value as a string for exact comparison
      eligibility = service_result[:overall_eligibility] || service_result['overall_eligibility']
      eligibility.to_s
    else
      # Default to overall_eligibility as string
      eligibility = service_result[:overall_eligibility] || service_result['overall_eligibility']
      eligibility.to_s
    end
  end

  def grade_result(actual_output, expected_output)
    # Normalize both outputs for comparison
    actual_normalized = actual_output.to_s.strip.downcase
    expected_normalized = expected_output.to_s.strip.downcase

    result = case @eval_set.grader_type
    when 'exact_match'
      actual_normalized == expected_normalized
    when 'contains'
      actual_normalized.include?(expected_normalized)
    when 'regex'
      pattern = @eval_set.grader_config['pattern']
      return false if pattern.blank?
      Regexp.new(pattern, Regexp::IGNORECASE).match?(actual_output.to_s)
    when 'json_schema'
      actual_normalized == expected_normalized
    else
      actual_normalized == expected_normalized
    end

    # Log comparison for debugging
    Rails.logger.info "Grading comparison (#{@eval_set.grader_type}): '#{actual_output}' vs '#{expected_output}' = #{result}"

    result
  end

  def create_eval_result(test_case, actual_output, expected_output, passed)
    if defined?(PromptEngine::EvalResult)
      # Also store input variables for detailed comparison
      PromptEngine::EvalResult.create!(
        eval_run: @eval_run,
        test_case: test_case,
        actual_output: actual_output.to_s,
        passed: passed
      )
      Rails.logger.info "✅ Created EvalResult record for test case #{test_case.id}"
    end
  rescue => e
    Rails.logger.error "❌ Could not create EvalResult record: #{e.message}"
    Rails.logger.error "Expected columns: #{PromptEngine::EvalResult.column_names}" if defined?(PromptEngine::EvalResult)
  end
end