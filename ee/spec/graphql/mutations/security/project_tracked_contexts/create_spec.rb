# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Security::ProjectTrackedContexts::Create, feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:current_user) { user }

  before_all do
    project.add_maintainer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  it { expect(described_class).to require_graphql_authorizations(:create_security_project_tracked_ref) }

  describe '#resolve' do
    let(:query_context) { { current_user: current_user } }
    let(:variables) do
      {
        project_path: project.full_path,
        refs: [
          { name: 'master', ref_type: 'BRANCH' }
        ]
      }
    end

    subject(:result) { resolve(described_class, args: variables, ctx: query_context) }

    context 'when user does not have permission' do
      let_it_be(:reporter) { create(:user, reporter_of: project) }
      let(:current_user) { reporter }

      it 'returns permission error' do
        expect(result[:errors]).to include('Insufficient permissions')
      end
    end
  end

  describe 'GraphQL integration tests' do
    subject(:execute) { GitlabSchema.execute(query, variables: variables, context: { current_user: current_user }) }

    let(:response) { execute.dig('data', 'securityRefsTrack') }

    let(:query) do
      <<~GQL
        mutation($input: SecurityRefsTrackInput!) {
          securityRefsTrack(input: $input) {
            trackedRefs {
              id
              name
              refType
            }
            errors
            clientMutationId
          }
        }
      GQL
    end

    context 'when tracking new valid refs' do
      let(:variables) do
        {
          input: {
            projectPath: project.full_path,
            refs: [
              { name: 'master', refType: 'BRANCH' }
            ],
            clientMutationId: "test-mutation-id"
          }
        }
      end

      it 'creates new tracked contexts' do
        expect { execute }.to change { Security::ProjectTrackedContext.count }.by(1)

        expect(response['errors']).to be_empty
        expect(response['trackedRefs'].size).to eq(1)
        expect(response['clientMutationId']).to eq('test-mutation-id')

        tracked_ref = response['trackedRefs'].first
        expect(tracked_ref['name']).to eq('master')
        expect(tracked_ref['refType']).to eq('BRANCH')
      end
    end

    context 'when tracking existing refs' do
      let(:variables) do
        {
          input: {
            projectPath: project.full_path,
            refs: [
              { name: 'master', refType: 'BRANCH' },
              { name: 'v1.1.0', refType: 'TAG' }
            ],
            clientMutationId: "test-mutation-id"
          }
        }
      end

      let!(:existing_branch_context) do
        create(:security_project_tracked_context, :tracked,
          project: project,
          context_name: 'master',
          context_type: :branch,
          is_default: false)
      end

      let!(:existing_tag_context) do
        create(:security_project_tracked_context, :tracked,
          project: project,
          context_name: 'v1.1.0',
          context_type: :tag,
          is_default: false)
      end

      it 'returns errors for duplicate contexts' do
        expect { execute }.not_to change { Security::ProjectTrackedContext.count }

        expect(response['errors']).to include(match(/already been taken/))
        expect(response['trackedRefs']).to be_empty
        expect(response['clientMutationId']).to eq('test-mutation-id')
      end
    end

    context 'when tracking non-existing refs' do
      let(:variables) do
        {
          input: {
            projectPath: project.full_path,
            refs: [
              { name: 'definitely-does-not-exist-branch', refType: 'BRANCH' },
              { name: 'definitely-does-not-exist-tag', refType: 'TAG' }
            ]
          }
        }
      end

      it 'returns errors for non-existing refs' do
        expect { execute }.not_to change { Security::ProjectTrackedContext.count }

        expect(response['errors']).to include('Ref does not exist in repository')
        expect(response['trackedRefs']).to be_empty
      end
    end

    context 'when tracking mixed existing and non-existing refs' do
      let!(:existing_context) do
        create(:security_project_tracked_context, :tracked,
          project: project,
          context_name: 'master',
          context_type: :branch,
          is_default: false)
      end

      let(:variables) do
        {
          input: {
            projectPath: project.full_path,
            refs: [
              { name: 'master', refType: 'BRANCH' },
              { name: 'definitely-does-not-exist-branch', refType: 'BRANCH' }
            ]
          }
        }
      end

      it 'returns errors for both duplicate and non-existing refs' do
        expect { execute }.not_to change { Security::ProjectTrackedContext.count }

        expect(response['trackedRefs']).to be_empty
        expect(response['errors']).to include('Ref does not exist in repository')
        expect(response['errors']).to include(match(/already been taken/))
      end
    end

    context 'when project does not exist' do
      let(:variables) do
        {
          input: {
            projectPath: 'non-existent/project',
            refs: [{ name: 'master', refType: 'BRANCH' }]
          }
        }
      end

      it 'returns project not found error' do
        expect(response['errors']).to include('Project not found')
        expect(response['trackedRefs']).to be_empty
      end
    end

    context 'with malformed input' do
      let(:variables) do
        {
          input: {
            projectPath: project.full_path,
            refs: [
              { name: 'master' }
            ]
          }
        }
      end

      it 'returns GraphQL validation error' do
        expect(execute['errors']).to be_present
        expect(execute['errors'].first['message']).to include('refType')
      end
    end

    context 'with empty refs array' do
      let(:variables) do
        {
          input: {
            projectPath: project.full_path,
            refs: []
          }
        }
      end

      it 'returns empty results' do
        expect(response['trackedRefs']).to be_empty
        expect(response['errors']).to be_empty
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: false)
      end

      let(:variables) do
        {
          input: {
            projectPath: project.full_path,
            refs: [{ name: 'master', refType: 'BRANCH' }]
          }
        }
      end

      it 'returns feature not available error' do
        expect(response['errors']).to include('Feature not available')
        expect(response['trackedRefs']).to be_empty
      end

      it 'does not create any tracked contexts' do
        expect { execute }.not_to change { Security::ProjectTrackedContext.count }
      end
    end
  end
end
