# frozen_string_literal: true

module AI
    module ValidityAnalysis
      class InventiveConcept
        MAPPING = {
          'Yes' => :inventive,
          'No' => :uninventive,
          '-' => :skipped
        }.freeze
  
        def initialize(llm_inventive_concept:, subject_matter:)
          @llm_inventive_concept = llm_inventive_concept
          @subject_matter = subject_matter
        end
  
        def value
          @value ||= MAPPING[llm_inventive_concept]
        end
  
        def forced_value
          subject_matter == :patentable ? :skipped : value
        end
  
        private
  
        attr_reader :llm_inventive_concept, :subject_matter
      end
    end
  end