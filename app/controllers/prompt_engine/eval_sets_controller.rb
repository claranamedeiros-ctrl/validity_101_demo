# Override PromptEngine's EvalSetsController to use our custom evaluation runner
require_dependency 'prompt_engine/eval_sets_controller'

module PromptEngine
  class EvalSetsController < ApplicationController
    # Keep all the original functionality but override the run action
    layout "prompt_engine/admin"

    before_action :set_prompt
    before_action :set_eval_set, only: [ :show, :edit, :update, :destroy, :run, :compare, :metrics ]

    def index
      @eval_sets = @prompt.eval_sets
    end

    def show
      # Handle different modes via URL parameters
      if params[:mode] == 'run_form'
        render_run_form and return
      elsif params[:mode] == 'results'
        render_results and return
      end

      @test_cases = @eval_set.test_cases
      @recent_runs = @eval_set.eval_runs.order(created_at: :desc).limit(5)
    end

    def new
      @eval_set = @prompt.eval_sets.build
    end

    def create
      @eval_set = @prompt.eval_sets.build(eval_set_params)

      if @eval_set.save
        redirect_to prompt_eval_set_path(@prompt, @eval_set), notice: "Evaluation set was successfully created."
      else
        flash.now[:alert] = "Please fix the errors below."
        render :new
      end
    end

    def edit
    end

    def update
      if @eval_set.update(eval_set_params)
        redirect_to prompt_eval_set_path(@prompt, @eval_set), notice: "Evaluation set was successfully updated."
      else
        flash.now[:alert] = "Please fix the errors below."
        render :edit
      end
    end

    def destroy
      @eval_set.destroy
      redirect_to prompt_eval_sets_path(@prompt), notice: "Evaluation set was successfully deleted."
    end

    def run
      # Use our custom evaluation runner instead of OpenAI Evals
      unless @eval_set.test_cases.any?
        redirect_to prompt_eval_set_path(@prompt, @eval_set),
          alert: "No test cases available. Please add test cases before running evaluation."
        return
      end

      # Get selected patent IDs from params, if any
      selected_patent_ids = params[:patent_ids].present? ? params[:patent_ids] : nil

      # Create new eval run with current prompt version
      @eval_run = @eval_set.eval_runs.create!(
        prompt_version: @prompt.current_version || @prompt.prompt_versions.first
      )

      # Store selected patent IDs in eval_run metadata if provided
      if selected_patent_ids
        @eval_run.update!(metadata: { selected_patent_ids: selected_patent_ids })
      end

      begin
        # Run evaluation using our custom runner (async for progress tracking)
        EvaluationJob.perform_later(@eval_run.id, selected_patent_ids)
        redirect_to prompt_eval_set_path(@prompt, @eval_set, mode: 'results'), notice: "Evaluation started! Results will appear below when complete."
      rescue => e
        @eval_run.update!(status: :failed, error_message: e.message)
        Rails.logger.error "Custom evaluation error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        redirect_to prompt_eval_set_path(@prompt, @eval_set), alert: "Evaluation failed: #{e.message}"
      end
    end

    private

    def render_run_form
      # Show form for selecting patents to run evaluation on
      all_patent_ids = @eval_set.test_cases.map do |tc|
        JSON.parse(tc.input_variables)['patent_id']
      end.uniq.sort

      # Build patent data with test case counts for each patent
      @patent_data = all_patent_ids.map do |patent_id|
        test_case_count = @eval_set.test_cases.count do |tc|
          JSON.parse(tc.input_variables)['patent_id'] == patent_id
        end
        { id: patent_id, test_case_count: test_case_count }
      end

      @total_test_cases = @eval_set.test_cases.count
      @patent_ids = all_patent_ids
      render 'run_form'
    end

    def render_results
      # Show detailed results with ground truth comparison
      @eval_runs = @eval_set.eval_runs.where(status: "completed").order(created_at: :desc).limit(10)
      @selected_run = nil
      @eval_results = []
      @detailed_comparison = []

      # Defensively handle run_id parameter
      if params[:run_id].present? && params[:run_id] != 'X'
        begin
          @selected_run = @eval_set.eval_runs.find(params[:run_id])
          @eval_results = if defined?(PromptEngine::EvalResult)
            @selected_run.eval_results.includes(:test_case).order(:id)
          else
            []
          end

          # Get ground truth data for comparison
          @ground_truth_data = load_ground_truth_data
          @detailed_comparison = build_detailed_comparison(@eval_results, @ground_truth_data)
        rescue ActiveRecord::RecordNotFound
          Rails.logger.warn "EvalRun with ID #{params[:run_id]} not found for eval_set #{@eval_set.id}"
          # Fall back to showing available runs without detailed comparison
        rescue => e
          Rails.logger.error "Error loading detailed results: #{e.message}"
          # Continue gracefully without detailed comparison
        end
      # Don't auto-select any run - user must explicitly choose from dropdown
      end

      render 'results'
    end

    def compare
      unless params[:run_ids].present? && params[:run_ids].is_a?(Array) && params[:run_ids].length == 2
        redirect_to prompt_eval_set_path(@prompt, @eval_set),
          alert: "Please select exactly two evaluation runs to compare."
        return
      end

      @run1 = @eval_set.eval_runs.find(params[:run_ids][0])
      @run2 = @eval_set.eval_runs.find(params[:run_ids][1])

      # Ensure both runs are completed
      unless @run1.status == "completed" && @run2.status == "completed"
        redirect_to prompt_eval_set_path(@prompt, @eval_set),
          alert: "Both evaluation runs must be completed to compare them."
        return
      end

      # Calculate comparison metrics
      @run1_success_rate = (@run1.total_count > 0) ? (@run1.passed_count.to_f / @run1.total_count * 100) : 0
      @run2_success_rate = (@run2.total_count > 0) ? (@run2.passed_count.to_f / @run2.total_count * 100) : 0
      @success_rate_diff = @run2_success_rate - @run1_success_rate
    rescue ActiveRecord::RecordNotFound
      redirect_to prompt_eval_set_path(@prompt, @eval_set),
        alert: "One or both evaluation runs could not be found."
    end

    def metrics
      # Get all completed runs for this eval set
      @eval_runs = @eval_set.eval_runs.where(status: "completed").order(created_at: :asc)

      # Calculate metrics data for charts
      if @eval_runs.any?
        # Success rate trend data (for line chart)
        @success_rate_trend = @eval_runs.map do |run|
          {
            date: run.created_at.strftime("%b %d, %Y %I:%M %p"),
            rate: (run.total_count > 0) ? (run.passed_count.to_f / run.total_count * 100).round(2) : 0,
            version: run.prompt_version ? "v#{run.prompt_version.version_number}" : "v1"
          }
        end

        # Success rate by version (for bar chart)
        version_stats = @eval_runs.group_by { |r| r.prompt_version&.version_number || 1 }
        @success_rate_by_version = version_stats.map do |version, runs|
          total_passed = runs.sum(&:passed_count)
          total_count = runs.sum(&:total_count)
          {
            version: "v#{version}",
            rate: (total_count > 0) ? (total_passed.to_f / total_count * 100).round(2) : 0,
            runs: runs.count
          }
        end.sort_by { |v| v[:version] }

        # Test case statistics
        @total_test_cases = @eval_set.test_cases.count
        @total_runs = @eval_runs.count
        @overall_pass_rate = begin
          total_passed = @eval_runs.sum(&:passed_count)
          total_tests = @eval_runs.sum(&:total_count)
          (total_tests > 0) ? (total_passed.to_f / total_tests * 100).round(2) : 0
        end

        # Average duration trend
        @duration_trend = @eval_runs.map do |run|
          duration = if run.completed_at && run.started_at
            (run.completed_at - run.started_at).to_i
          else
            nil
          end
          {
            date: run.created_at.strftime("%b %d, %Y %I:%M %p"),
            duration: duration,
            version: run.prompt_version ? "v#{run.prompt_version.version_number}" : "v1"
          }
        end.compact

        # Recent activity (last 10 runs)
        @recent_activity = @eval_runs.last(10).reverse
      else
        @success_rate_trend = []
        @success_rate_by_version = []
        @total_test_cases = @eval_set.test_cases.count
        @total_runs = 0
        @overall_pass_rate = 0
        @duration_trend = []
        @recent_activity = []
      end
    end

    protected

    helper_method :api_key_configured?, :safe_grader_config

    def safe_grader_config(eval_set)
      config = eval_set.read_attribute(:grader_config)
      return {} if config.nil?
      return config if config.is_a?(Hash)

      begin
        JSON.parse(config.to_s)
      rescue JSON::ParserError, NoMethodError
        {}
      end
    end

    helper_method :api_key_configured?

    private

    def set_prompt
      @prompt = PromptEngine::Prompt.find(params[:prompt_id])
    end

    def set_eval_set
      begin
        @eval_set = @prompt.eval_sets.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        # Handle case where evaluation set ID doesn't exist (e.g., after deletion/restoration)
        # Redirect to the first available evaluation set for this prompt
        first_eval_set = @prompt.eval_sets.first
        if first_eval_set
          Rails.logger.info "EvalSet #{params[:id]} not found, redirecting to #{first_eval_set.id}"
          redirect_to "/prompt_engine/prompts/#{@prompt.id}/eval_sets/#{first_eval_set.id}#{request.query_string.present? ? '?' + request.query_string : ''}",
                      notice: "Evaluation set not found. Redirected to available evaluation set."
          return
        else
          # No evaluation sets exist for this prompt
          redirect_to "/prompt_engine/prompts/#{@prompt.id}/eval_sets",
                      alert: "No evaluation sets found for this prompt."
          return
        end
      end
    end

    def eval_set_params
      params.require(:eval_set).permit(:name, :description, :grader_type, grader_config: {})
    end

    def api_key_configured?
      # Check if OpenAI API key is available from Settings or Rails credentials
      settings = PromptEngine::Setting.instance
      settings.openai_configured? || Rails.application.credentials.dig(:openai, :api_key).present?
    rescue ActiveRecord::RecordNotFound
      # If settings record doesn't exist, check Rails credentials
      Rails.application.credentials.dig(:openai, :api_key).present?
    end

    def load_ground_truth_data
      # Load ground truth data from NEW transformed CSV file
      ground_truth_file = Rails.root.join('groundt', 'gt_transformed_for_llm.csv')
      return {} unless File.exist?(ground_truth_file)

      ground_truth = {}
      CSV.foreach(ground_truth_file, headers: true, encoding: 'UTF-8') do |row|
        key = "#{row['patent_number']}_#{row['claim_number']}"

        # NO mapping needed - values already match LLM schema exactly!
        ground_truth[key] = {
          patent_number: row['patent_number'],
          claim_number: row['claim_number'].to_i,
          claim_text: row['claim_text'],
          abstract: row['abstract'],
          subject_matter: row['gt_subject_matter'],
          inventive_concept: row['gt_inventive_concept'],
          overall_eligibility: row['gt_overall_eligibility']
        }
      end
      ground_truth
    rescue => e
      Rails.logger.error "Failed to load ground truth data: #{e.message}"
      {}
    end

    def build_detailed_comparison(eval_results, ground_truth_data)
      comparisons = []

      eval_results.each do |result|
        begin
          input_vars = JSON.parse(result.test_case.input_variables)
          patent_id = input_vars['patent_id']
          claim_number = input_vars['claim_number']
          key = "#{patent_id}_#{claim_number}"

          # Parse actual output - now always stored as JSON with all 3 fields
          actual_data = begin
            JSON.parse(result.actual_output)
          rescue JSON::ParserError
            # Fallback for legacy data that might still be strings
            { overall_eligibility: result.actual_output }
          end

          ground_truth = ground_truth_data[key] || {}

          comparison = {
            patent_id: patent_id,
            claim_number: claim_number,
            test_case: result.test_case,
            passed: result.passed,
            actual: actual_data,
            expected: ground_truth,
            differences: calculate_differences(actual_data, ground_truth)
          }

          comparisons << comparison
        rescue => e
          Rails.logger.error "Error building comparison for result #{result.id}: #{e.message}"
        end
      end

      comparisons
    end

    def calculate_differences(actual, expected)
      differences = []

      %w[subject_matter inventive_concept overall_eligibility].each do |field|
        actual_value = actual[field] || actual[field.to_sym]
        expected_value = expected[field] || expected[field.to_sym]

        if actual_value != expected_value
          differences << {
            field: field.humanize,
            actual: actual_value,
            expected: expected_value
          }
        end
      end

      differences
    end
  end
end