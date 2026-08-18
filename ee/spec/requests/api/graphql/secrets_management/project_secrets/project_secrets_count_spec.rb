# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.projectSecretsCount', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers
  include SecretsManagement::GitlabSecretsManagerHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let(:secrets_manager) { create(:project_secrets_manager, project: project) }

  let(:query) do
    graphql_query_for('projectSecretsCount', { project_path: project.full_path })
  end

  before_all do
    project.add_owner(current_user)
  end

  shared_examples 'returns null' do
    it 'returns null with no error' do
      expect(graphql_data['projectSecretsCount']).to be_nil
      expect(graphql_errors).to be_nil
    end
  end

  context 'when secrets manager is active' do
    before do
      stub_licensed_features(native_secrets_management: true)
      provision_project_secrets_manager(secrets_manager, current_user)
    end

    context 'when there are no secrets' do
      it 'returns 0' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data['projectSecretsCount']).to eq(0)
      end
    end

    context 'when there are secrets' do
      before do
        create_project_secret(
          user: current_user, project: project, name: 'SECRET_1', value: 'v1', environment: '*', branch: '*'
        )
        create_project_secret(
          user: current_user, project: project, name: 'SECRET_2', value: 'v2', environment: '*', branch: '*'
        )
      end

      it 'returns the correct count' do
        post_graphql(query, current_user: current_user)

        expect(graphql_data['projectSecretsCount']).to eq(2)
      end
    end
  end

  context 'when secrets manager exists but is not active' do
    before do
      stub_licensed_features(native_secrets_management: true)

      create(:project_secrets_manager, :provisioning, project: project)
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'returns null'
  end

  context 'when secrets manager does not exist' do
    before do
      stub_licensed_features(native_secrets_management: true)

      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'returns null'
  end

  context 'when user does not have access' do
    let_it_be(:other_user) { create(:user) }

    before do
      stub_licensed_features(native_secrets_management: true)

      post_graphql(query, current_user: other_user)
    end

    it_behaves_like 'returns null'
  end

  context 'when feature flag is disabled' do
    before do
      stub_licensed_features(native_secrets_management: true)
      stub_feature_flags(secrets_manager: false)

      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'returns null'
  end
end
