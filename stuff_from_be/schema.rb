# frozen_string_literal: true

module AI
    module ValidityAnalysis
      class Schema < RubyLLM::Schema
        string :patent_number, description: 'The patent number as inputted by the user'
        number :claim_number, description: 'The claim number evaluated for the patent, as inputted by the user'
        string :subject_matter, enum: %w[abstract natural_phenomenon patentable],
                                description: 'The subject matter of the claim'
        string :inventive_concept, enum: %w[inventive uninventive skipped],
                                   description: 'The inventive concept of the claim'
        number :validity_score, minimum: 1, maximum: 5, description: 'Score from 1 to 5 with the validity strength'
      end
    end
  end