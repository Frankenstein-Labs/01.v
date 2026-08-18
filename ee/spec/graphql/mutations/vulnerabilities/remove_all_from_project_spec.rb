# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Vulnerabilities::RemoveAllFromProject, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project1) { create(:project) }
  let_it_be(:project2) { create(:project) }
  let_it_be(:project3) { create(:project) }
  let_it_be(:current_user) { create(:user, owner_of: [project1, project2]) }

  let(:klass) { described_class.new(object: nil, context: query_context, field: nil) }
  let(:project_ids) { [project1, project2].map(&:to_global_id) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe '#resolve' do
    subject(:mutation) do
      klass.resolve(
        project_ids: project_ids,
        resolved_on_default_branch: true
      )
    end

    it 'calls the service object with correct arguments' do
      expect(Vulnerabilities::ScheduleRemovingAllFromProjectService)
        .to receive(:new).with(a_collection_containing_exactly(project1, project2), true).and_call_original

      mutation
    end

    it 'returns the list of Projects affected', :aggregate_failures do
      expect(mutation[:projects]).to match_array([project1, project2])
      expect(mutation[:errors]).to be_empty
    end

    context 'when no project IDs are given' do
      let(:project_ids) { [] }

      it 'raises ArgumentError' do
        expect { mutation }.to raise_error(Gitlab::Graphql::Errors::ArgumentError)
      end
    end

    context 'when user does not have access to any of the projects' do
      let(:project_ids) { [project1, project2, project3].map(&:to_global_id) }

      it 'raises ResourceNotAvailable if any of the projects is not accessible' do
        expect { mutation }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end
end
