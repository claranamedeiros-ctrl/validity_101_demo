# frozen_string_literal: true
module Ai
  module ValidityAnalysis
    class OverallEligibility
      OVERALL_ELIGIBILITY_ERROR_MESSAGE =
        'Subject matter was identified as %<subject_matter>s but cannot determine inventive concept'
      INCORRECT_DATA_ERROR_MESSAGE =
        'LLM respond with incorrect data. Subject matter: %<subject_matter>s, inventive concept: %<inventive_concept>s'

      RULES = {
        %i[patentable skipped]      => :eligible,
        %i[patentable inventive]    => :eligible,
        %i[patentable uninventive]  => :eligible,
        %i[abstract skipped]        => :error,
        %i[abstract inventive]      => :eligible,
        %i[abstract uninventive]    => :ineligible,
        %i[natural_phenomenon skipped]     => :error,
        %i[natural_phenomenon inventive]   => :eligible,
        %i[natural_phenomenon uninventive] => :ineligible
      }.freeze

      def initialize(subject_matter:, inventive_concept:)
        @subject_matter = subject_matter
        @inventive_concept = inventive_concept
      end

      def value
        @value ||= RULES.fetch([@subject_matter, @inventive_concept], nil)
      end

      def invalid?
        value.nil? || value == :error
      end

      def error_message
        if value == :error
          format(OVERALL_ELIGIBILITY_ERROR_MESSAGE, subject_matter: @subject_matter)
        elsif value.nil?
          format(INCORRECT_DATA_ERROR_MESSAGE, subject_matter: @subject_matter, inventive_concept: @inventive_concept)
        end
      end
    end
  end
end