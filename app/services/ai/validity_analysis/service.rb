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

        # 3) Map LLM output through backend mapping classes (backend/service.rb:69-79)
        subject_matter_obj = Ai::ValidityAnalysis::SubjectMatter.new(
          llm_subject_matter: raw[:subject_matter]
        )

        inventive_concept_obj = Ai::ValidityAnalysis::InventiveConcept.new(
          llm_inventive_concept: raw[:inventive_concept],
          subject_matter: subject_matter_obj.value
        )

        # 4) Determine overall eligibility (backend/service.rb:88-93)
        overall_eligibility_obj = Ai::ValidityAnalysis::OverallEligibility.new(
          subject_matter: subject_matter_obj.value,
          inventive_concept: inventive_concept_obj.value
        )

        if overall_eligibility_obj.invalid?
          return {
            status: :error,
            status_message: overall_eligibility_obj.error_message || ERROR_MESSAGE
          }
        end

        # 5) Normalize validity score (backend/service.rb:82-86)
        validity_score_obj = Ai::ValidityAnalysis::ValidityScore.new(
          validity_score: raw[:validity_score],
          overall_eligibility: overall_eligibility_obj.value
        )

        # We log but don't fail on invalid scores (backend/service.rb:24-27)
        if validity_score_obj.invalid?
          Rails.logger.error { validity_score_obj.error_message }
        end

        # 6) Return with forced values (backend/service.rb:95-104)
        {
          status: :success,
          status_message: nil,
          # Echo inputs
          patent_number: raw[:patent_number] || patent_number,
          claim_number: raw[:claim_number] || claim_number.to_i,
          # Mapped values using backend logic with forced_value methods
          subject_matter: subject_matter_obj.value,
          inventive_concept: inventive_concept_obj.forced_value, # Forces :skipped if patentable!
          validity_score: validity_score_obj.forced_value, # Forces 3 or 2 if inconsistent!
          overall_eligibility: overall_eligibility_obj.value
        }
      rescue => e
        Rails.logger.error("Validity 101 error: #{e.message}")
        { status: :error, status_message: ERROR_MESSAGE }
      end
    end
  end
end
