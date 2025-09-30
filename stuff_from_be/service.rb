# frozen_string_literal: true

module AI
    module ValidityAnalysis
      class Service
        ERROR_MESSAGE = 'Failed to analyze patent validity.'
        LLM_TEMPERATURE = 0.1
  
        def initialize(user:, patent:, patent_detail:, independent_claim:)
          @user = user
          @patent = patent
          @patent_detail = patent_detail
          @independent_claim = independent_claim
        end
  
        def call
          if overall_eligibility.invalid?
            error_message = overall_eligibility.error_message
            Rails.logger.error { error_message }
            return update_ai_validity_analysis_detail_with_error!(error_message)
          end
  
          # We do not fail the analysis if the validity score is invalid, but we log the error.
          if validity_score.invalid?
            error_message = validity_score.error_message
            Rails.logger.error { error_message }
          end
  
          update_ai_validity_analysis_detail_with_success!
        rescue StandardError => error
          Rails.logger.error { "Unexpected error. Error: #{error.message}" }
          update_ai_validity_analysis_detail_with_error!
        end
  
        private
  
        delegate :ai_validity_analysis_detail, to: :@patent
  
        def agent_response
          @agent_response ||=
            chat.with_temperature(LLM_TEMPERATURE).with_instructions(agent_setting.system_prompt).ask(
              agent_setting.user_prompt(user_prompt_context)
            ).content.with_indifferent_access
        end
  
        def chat
          @chat ||= AI::ValidityAnalysis::Chat.create!(
            user: @user,
            ai_validity_analysis_detail: ai_validity_analysis_detail,
            ai_agent_setting: agent_setting,
            model_id: agent_setting.model_id
          ).with_schema(Schema)
        end
  
        def agent_setting
          @agent_setting ||= AI::ValidityAnalysis::AgentSetting.find_sole_by(active: true)
        end
  
        def user_prompt_context
          {
            patent_id: @patent.external_id,
            claim_number: @independent_claim.number,
            claim_text: @independent_claim.text,
            abstract: @patent_detail.abstract
          }
        end
  
        def subject_matter
          agent_response[:subject_matter]
        end
  
        def inventive_concept
          agent_response[:inventive_concept]
        end
  
        def validity_score
          @validity_score ||= AI::ValidityAnalysis::ValidityScore.new(
            validity_score: agent_response[:validity_score],
            overall_eligibility: overall_eligibility.value
          )
        end
  
        def overall_eligibility
          @overall_eligibility ||= AI::ValidityAnalysis::OverallEligibility.new(
            subject_matter: subject_matter,
            inventive_concept: inventive_concept
          )
        end
  
        def update_ai_validity_analysis_detail_with_success!
          ai_validity_analysis_detail.update!(
            status: :success,
            status_message: nil,
            subject_matter: subject_matter,
            inventive_concept: subject_matter == 'patentable' ? 'skipped' : inventive_concept,
            validity_score: validity_score.forced_value,
            overall_eligibility: overall_eligibility.value
          )
        end
  
        def update_ai_validity_analysis_detail_with_error!(error_message = ERROR_MESSAGE)
          ai_validity_analysis_detail.update!(
            status: :error,
            status_message: error_message,
            subject_matter: nil,
            inventive_concept: nil,
            validity_score: nil,
            overall_eligibility: nil
          )
        end
      end
    end
  end