# frozen_string_literal: true

module AI
    module ValidityAnalysis
      class ValidityScore
        INCORRECT_DATA_ERROR_MESSAGE =
          'LLM respond with incorrect data. ' \
          'Validity score: %<validity_score>s, ' \
          'overall eligibility: %<overall_eligibility>s'
  
        def initialize(validity_score:, overall_eligibility:)
          @validity_score = validity_score
          @overall_eligibility = overall_eligibility
        end
  
        def value
          validity_score
        end
  
        def forced_value
          if overall_eligibility == :eligible && validity_score < 3
            3
          elsif overall_eligibility == :ineligible && validity_score >= 3
            2
          else
            validity_score
          end
        end
  
        def invalid?
          (overall_eligibility == :eligible && validity_score < 3) ||
            (overall_eligibility == :ineligible && validity_score >= 3)
        end
  
        def error_message
          format(INCORRECT_DATA_ERROR_MESSAGE, validity_score: validity_score, overall_eligibility: overall_eligibility)
        end
  
        private
  
        attr_reader :validity_score, :overall_eligibility
      end
    end
  end