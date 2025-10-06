# frozen_string_literal: true

require_relative 'subject_matter'
require_relative 'inventive_concept'
require_relative 'overall_eligibility'
require_relative 'validity_score'

module Ai
  module ValidityAnalysis
    class Service
      LLM_TEMPERATURE = 0.1
      ERROR_MESSAGE = 'Failed to analyze patent validity.'

      def call(patent_number:, claim_number:, claim_text:, abstract:)
        # 1) Render the prompt from PromptEngine (variables + runtime options)
        rendered = PromptEngine.render(
          "validity-101-agent",
          variables: {
            patent_id: patent_number,
            claim_number: claim_number,
            claim_text: claim_text,
            abstract: abstract
          }
        )

        # 2) Execute with RubyLLM
        chat = RubyLLM.chat(provider: "openai", model: rendered[:model] || "gpt-4o")

        # For GPT-5: use JSON mode without strict schema (GPT-5 doesn't support json_schema)
        # For GPT-4: use strict schema validation
        if rendered[:model]&.start_with?('gpt-5')
          # GPT-5: Use json_object mode (not json_schema)
          chat_configured = chat
            .with_params(
              max_completion_tokens: rendered[:max_tokens] || 1200,
              response_format: { type: "json_object" }
            )
            .with_instructions(rendered[:system_message].to_s)

          response = chat_configured.ask(rendered[:content].to_s)
        else
          # GPT-4: Use strict schema
          schema = {
            type: "object",
            properties: {
              patent_number: { type: "string", description: "The patent number as inputted by the user" },
              claim_number: { type: "number", description: "The claim number evaluated for the patent, as inputted by the user" },
              subject_matter: {
                type: "string",
                enum: ["Abstract", "Natural Phenomenon", "Not Abstract/Not Natural Phenomenon"],
                description: "The output determined for Alice Step One"
              },
              inventive_concept: {
                type: "string",
                enum: ["No", "Yes", "-"],
                description: "The output determined for Alice Step Two"
              },
              validity_score: {
                type: "number",
                minimum: 1,
                maximum: 5,
                description: "The validity score from 1 to 5 determined for the patent claim"
              }
            },
            required: ["patent_number", "claim_number", "subject_matter", "inventive_concept", "validity_score"],
            additionalProperties: false
          }

          chat_configured = chat
            .with_schema(schema)
            .with_temperature(rendered[:temperature] || LLM_TEMPERATURE)
            .with_params(max_completion_tokens: rendered[:max_tokens] || 1200)
            .with_instructions(rendered[:system_message].to_s)

          response = chat_configured.ask(rendered[:content].to_s)
        end

        # Handle case where response.content might be a String instead of Hash
        raw = if response.content.is_a?(Hash)
          response.content.with_indifferent_access
        elsif response.content.is_a?(String)
          # Try to parse JSON string
          JSON.parse(response.content).with_indifferent_access rescue raise("API returned string: #{response.content}")
        else
          raise("Unexpected response type: #{response.content.class}")
        end

        # 3) Calculate overall_eligibility from Alice Test logic
        # This is NOT a forced value - it's the actual test result
        subject_matter = raw[:subject_matter]
        inventive_concept = raw[:inventive_concept]

        # Alice Test: Eligible if NOT directed to abstract/natural phenomenon,
        # OR if it has an inventive concept
        overall_eligibility = if subject_matter == "Not Abstract/Not Natural Phenomenon"
          "Eligible"
        elsif inventive_concept == "Yes"
          "Eligible"
        else
          "Ineligible"
        end

        # 4) Return RAW LLM outputs directly (no forced values!)
        {
          status: :success,
          status_message: nil,
          # Echo inputs
          patent_number: raw[:patent_number] || patent_number,
          claim_number: raw[:claim_number] || claim_number.to_i,
          # RAW LLM outputs - exactly what the LLM said
          subject_matter: subject_matter,
          inventive_concept: inventive_concept,
          validity_score: raw[:validity_score],
          # Calculated overall eligibility based on Alice Test logic
          overall_eligibility: overall_eligibility
        }
      rescue => e
        # Detailed error logging for debugging batch failures
        error_details = {
          timestamp: Time.current.iso8601,
          patent_number: patent_number,
          error_class: e.class.name,
          error_message: e.message,
          backtrace: e.backtrace.first(10)
        }

        Rails.logger.error("=" * 80)
        Rails.logger.error("VALIDITY ANALYSIS ERROR - #{patent_number}")
        Rails.logger.error("Error Class: #{e.class}")
        Rails.logger.error("Error Message: #{e.message}")
        Rails.logger.error("Full Backtrace:")
        Rails.logger.error(e.backtrace.join("\n"))
        Rails.logger.error("=" * 80)

        # Also log to a dedicated error file for easy debugging
        File.open(Rails.root.join('log', 'patent_evaluation_errors.log'), 'a') do |f|
          f.puts "\n#{'-' * 80}"
          f.puts "Timestamp: #{error_details[:timestamp]}"
          f.puts "Patent: #{patent_number}"
          f.puts "Error: #{e.class} - #{e.message}"
          f.puts "Backtrace:\n#{error_details[:backtrace].join("\n")}"
          f.puts '-' * 80
        end

        { status: :error, status_message: ERROR_MESSAGE, error: "#{e.class}: #{e.message}" }
      end
    end
  end
end
