# frozen_string_literal: true

require_relative 'overall_eligibility'
require_relative 'validity_score'

module AI
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
        # 2) Execute with RubyLLM and our Schema (system + user)
        schema = {
          type: "object",
          properties: {
            patent_number: { type: "string", description: "The patent number as inputted by the user" },
            claim_number: { type: "number", description: "The claim number evaluated for the patent, as inputted by the user" },
            subject_matter: {
              type: "string",
              enum: ["abstract", "natural_phenomenon", "patentable"],
              description: "The subject matter of the claim"
            },
            inventive_concept: {
              type: "string",
              enum: ["inventive", "uninventive", "skipped"],
              description: "The inventive concept of the claim"
            },
            validity_score: {
              type: "number",
              minimum: 1,
              maximum: 5,
              description: "Score from 1 to 5 with the validity strength"
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

        raw = response.content.with_indifferent_access # Hash: {patent_number, claim_number, subject_matter, inventive_concept, validity_score}

        # 3) Infer eligibility (using raw values first  mirroring your backend)
        eligibility = AI::ValidityAnalysis::OverallEligibility.new(
          subject_matter: raw[:subject_matter],
          inventive_concept: raw[:inventive_concept]
        )

        if eligibility.invalid?
          return {
            status: :error,
            status_message: eligibility.error_message || ERROR_MESSAGE
          }
        end

        # 4) Normalize score against inferred eligibility
        vs = AI::ValidityAnalysis::ValidityScore.new(
          validity_score: raw[:validity_score],
          overall_eligibility: eligibility.value
        )
        normalized_score = vs.forced_value

        # 5) "Persist" step: replicate your backend by discarding Step-2 ONLY NOW if patentable
        final_inventive = (raw[:subject_matter] == 'patentable') ? 'skipped' : raw[:inventive_concept]

        {
          status: :success,
          status_message: nil,
          # echo inputs
          patent_number: raw[:patent_number] || patent_number,
          claim_number: raw[:claim_number] || claim_number.to_i,
          # LLM fields (with late overwrite to mirror your backend)
          subject_matter: raw[:subject_matter],
          inventive_concept: final_inventive,
          validity_score: normalized_score,
          overall_eligibility: eligibility.value
        }
      rescue => e
        Rails.logger.error("Validity 101 error: #{e.message}")
        { status: :error, status_message: ERROR_MESSAGE }
      end
    end
  end
end