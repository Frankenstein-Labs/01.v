# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'project', feature_category: :groups_and_projects do
  include GraphqlHelpers
  include Ai::Catalog::FlowFactoryHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, :public, group: group) }
  let_it_be(:current_user) { create(:user, guest_of: project) }

  let(:params) { {} }

  describe 'autocompleteUsers.duoStatus field' do
    let(:query) do
      graphql_query_for(
        'project',
        { 'fullPath' => project.full_path },
        query_graphql_field(
          'autocompleteUsers',
          params,
          <<~QUERY
          username
          duoStatus {
            disabled
            disabledReason
            flowTriggerEvents
          }
          QUERY
        )
      )
    end

    let(:user) { current_user }
    let(:user_data) { graphql_data.dig('project', 'autocompleteUsers').find { |u| u['username'] == user.username } }

    context 'when user type is human' do
      it 'returns null' do
        post_graphql(query, current_user: current_user)

        expect(user_data['username']).to eq(user.username)
        expect(user_data['duoStatus']).to be_nil
      end
    end

    context 'when user is a regular service account' do
      let!(:user) do
        create(:user, :service_account, guest_of: project, composite_identity_enforced: false)
      end

      it 'returns null' do
        post_graphql(query, current_user: current_user)

        expect(user_data['username']).to eq(user.username)
        expect(user_data['duoStatus']).to be_nil
      end
    end

    context 'when user is a composite identity user' do
      let(:user) do
        create(:composite_identity_service_account_for_project, project: project)
      end

      before do
        create_flow_configuration_for_project(project, user, [1, 2])

        allow_next_instance_of(
          ::Ai::UsageQuotaService,
          user: current_user
        ) do |instance|
          allow(instance).to receive(:execute).and_return(
            ServiceResponse.error(reason: :usage_quota_exceeded, message: 'No credits available')
          )
        end
      end

      it 'returns the Duo status' do
        post_graphql(query, current_user: current_user)

        expect(user_data['username']).to eq(user.username)
        expect(user_data['duoStatus']).to match(
          'disabled' => true,
          'disabledReason' => 'Unavailable - no credits',
          'flowTriggerEvents' => %w[ASSIGN ASSIGN_REVIEWER]
        )
      end
    end
  end
end
