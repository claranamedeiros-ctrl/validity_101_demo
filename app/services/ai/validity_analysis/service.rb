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

        # 2) Execute with RubyLLM and Backend Schema (MUST match backend/schema.rb exactly!)
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

        chat = RubyLLM.chat(provider: "openai", model: rendered[:model] || "gpt-4o")
        response = chat.with_schema(schema)
                       .with_temperature(rendered[:temperature] || LLM_TEMPERATURE)
                       .with_params(max_tokens: rendered[:max_tokens] || 1200)
                       .with_instructions(rendered[:system_message].to_s)
                       .ask(rendered[:content].to_s)

        raw = response.content.with_indifferent_access

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
        Rails.logger.error("Validity 101 error: #{e.message}")
        { status: :error, status_message: ERROR_MESSAGE }
      end
    end
  end
end
