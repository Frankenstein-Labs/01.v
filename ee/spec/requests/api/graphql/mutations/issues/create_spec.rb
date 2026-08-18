# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create an issue', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, developers: current_user) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:cadence) { create(:iterations_cadence, group: group) }
  let_it_be(:current_iteration) { create(:iteration, iterations_cadence: cadence, start_date: 2.days.ago, due_date: 10.days.from_now) }

  let(:input) do
    {
      'title' => 'new title',
      'weight' => 2,
      'healthStatus' => 'atRisk',
      'iterationWildcardId' => 'CURRENT',
      'iterationCadenceId' => current_iteration.iterations_cadence.to_global_id.to_s
    }
  end

  let(:mutation) { graphql_mutation(:createIssue, input.merge('projectPath' => project.full_path)) }

  let(:mutation_response) { graphql_mutation_response(:create_issue) }

  before do
    stub_licensed_features(issuable_health_status: true, iterations: true)
  end

  it 'creates the issue' do
    post_graphql_mutation(mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['issue']).to include(input.except('iterationWildcardId', 'iterationCadenceId'))
    expect(mutation_response['issue']).to include('iteration' => hash_including('id' => current_iteration.to_global_id.to_s))
  end

  context 'when iterationId is provided' do
    let(:input) do
      {
        'title' => 'new title',
        'weight' => 2,
        'healthStatus' => 'atRisk',
        'iterationId' => current_iteration.to_global_id.to_s
      }
    end

    it 'creates the issue' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['issue']).to include(input.except('iterationId'))
      expect(mutation_response['issue']).to include('iteration' => hash_including('id' => current_iteration.to_global_id.to_s))
    end

    context 'when iterationId and iterationWildcardId are provided' do
      let(:input) do
        {
          'title' => 'new title',
          'weight' => 2,
          'healthStatus' => 'atRisk',
          'iterationId' => current_iteration.to_global_id.to_s,
          'iterationWildcardId' => 'CURRENT',
          'iterationCadenceId' => current_iteration.iterations_cadence.to_global_id.to_s
        }
      end

      it 'returns a mutually exclusive argument error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(graphql_errors).to contain_exactly(hash_including('message' => 'Incompatible arguments: iterationId, iterationWildcardId.'))
      end
    end
  end

  context 'when status is provided' do
    let(:status) { build(:work_item_system_defined_status, :in_progress) }
    let(:status_gid) { status.to_gid.to_s }

    let(:input) do
      {
        'title' => 'New title',
        'statusId' => status_gid
      }
    end

    before do
      stub_licensed_features(work_item_status: true)
    end

    subject(:expected_status) do
      work_item_id = GlobalID.parse(mutation_response['issue']['id']).model_id.to_i
      ::WorkItems::Statuses::CurrentStatus.find_by(work_item_id: work_item_id)&.status
    end

    shared_examples 'a successful mutation' do
      it 'creates the work item with correct status' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty

        is_expected.to eq(status)
      end
    end

    it_behaves_like 'a successful mutation'

    context 'with custom status' do
      let!(:lifecycle) do
        create(:work_item_custom_lifecycle, namespace: group, work_item_types: [build(:work_item_system_defined_type, :issue)])
      end

      let(:status) { create(:work_item_custom_status, name: 'In review', lifecycles: [lifecycle]) }

      it_behaves_like 'a successful mutation'
    end

    context 'when status gid references non-existing system-defined status' do
      let(:status_gid) { 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/99' }

      it_behaves_like 'a mutation that returns top-level errors', errors: ["Status doesn't exist."]
    end

    context 'when status gid references non-existing custom status' do
      let(:status_gid) { "gid://gitlab/WorkItems::Statuses::Custom::Status/#{non_existing_record_id}" }

      it_behaves_like 'a mutation that returns top-level errors', errors: ["Status doesn't exist."]
    end
  end
end
