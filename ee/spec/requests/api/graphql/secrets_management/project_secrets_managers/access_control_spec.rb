# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'project secrets manager', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:project_secrets_manager) { create(:project_secrets_manager, project: project) }
  let_it_be(:current_user) { create(:user) }

  let(:query) do
    graphql_query_for(
      'projectSecretsManager',
      { project_path: project.full_path },
      all_graphql_fields_for('ProjectSecretsManager', max_depth: 2)
    )
  end

  before do
    stub_licensed_features(native_secrets_management: true)
    enroll_instance_in_secrets_manager
  end

  context 'when current user is not part of the project' do
    before do
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is a guest' do
    before_all do
      project.add_guest(current_user)
    end

    before do
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is the project owner' do
    before_all do
      project.add_owner(current_user)
    end

    before do
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a working graphql query that returns data'

    it 'returns the details about the secrets manager' do
      expect(graphql_data_at(:project_secrets_manager))
        .to match(a_graphql_entity_for(
          project: a_graphql_entity_for(project),
          status: 'PROVISIONING'
        ))
    end
  end
end
