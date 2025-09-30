# frozen_string_literal: true

module AI
  module ValidityAnalysis
    class SubjectMatter
      MAPPING = {
        'Abstract' => :abstract,
        'Natural Phenomenon' => :natural_phenomenon,
        'Not Abstract/Not Natural Phenomenon' => :patentable
      }.freeze

      def initialize(llm_subject_matter:)
        @llm_subject_matter = llm_subject_matter
      end

      def value
        @value ||= MAPPING[llm_subject_matter]
      end

      private

      attr_reader :llm_subject_matter
    end
  end
end