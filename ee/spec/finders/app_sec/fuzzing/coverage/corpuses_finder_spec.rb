# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppSec::Fuzzing::Coverage::CorpusesFinder, feature_category: :fuzz_testing do
  let_it_be(:corpus1) { create(:corpus) }
  let_it_be(:corpus2) { create(:corpus, project: corpus1.project, user: corpus1.user) }
  let_it_be(:corpus3) { create(:corpus) }

  subject(:finder) { described_class.new(project: corpus1.project).execute }

  describe '#execute' do
    it 'returns corpuses records' do
      aggregate_failures do
        expect(finder).to contain_exactly(corpus1, corpus2)
      end
    end

    context 'when the corpus does not exist' do
      subject(:finder) { described_class.new(project: 0).execute }

      it 'returns an empty relation' do
        expect(finder).to be_empty
      end
    end
  end
end
