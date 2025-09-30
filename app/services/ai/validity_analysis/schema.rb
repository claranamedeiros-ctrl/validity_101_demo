# frozen_string_literal: true

module AI
  module ValidityAnalysis
    class Schema < RubyLLM::Schema
      string :patent_number, description: 'The patent number as inputted by the user'
      number :claim_number, description: 'The claim number evaluated for the patent, as inputted by the user'
      string :subject_matter, enum: ['Abstract', 'Natural Phenomenon', 'Not Abstract/Not Natural Phenomenon'],
                              description: 'The output determined for Alice Step One'
      string :inventive_concept, enum: ['No', 'Yes', '-'], description: 'The output determined for Alice Step Two'
      number :validity_score, minimum: 1, maximum: 5,
                              description: 'The validity score from 1 to 5 determined for the patent claim'
    end
  end
end