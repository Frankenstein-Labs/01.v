# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::AppSec::Fuzzing::Coverage::Corpus::Create, feature_category: :fuzz_testing do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:package) { create(:generic_package, project: project, creator: current_user) }

  let(:corpus) { AppSec::Fuzzing::Coverage::Corpus.find_by(user: current_user, project: project) }

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  before do
    stub_licensed_features(coverage_fuzzing: true)
  end

  specify { expect(described_class).to require_graphql_authorizations(:create_coverage_fuzzing_corpus) }

  describe '#resolve' do
    subject(:resolve) do
      mutation.resolve(
        full_path: project.full_path,
        package_id: package.to_global_id
      )
    end

    context 'when the feature is licensed' do
      context 'when the user can create a corpus' do
        it 'returns the corpus' do
          expect(resolve[:corpus]).to eq(corpus)
        end
      end
    end
  end
end
