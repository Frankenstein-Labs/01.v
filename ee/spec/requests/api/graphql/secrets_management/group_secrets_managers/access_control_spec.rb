# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'group secrets manager', :gitlab_secrets_manager, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:group_secrets_manager) { create(:group_secrets_manager, group: group) }
  let_it_be(:current_user) { create(:user) }

  let(:query) do
    graphql_query_for(
      'groupSecretsManager',
      { group_path: group.full_path },
      all_graphql_fields_for('GroupSecretsManager', max_depth: 2)
    )
  end

  before do
    stub_licensed_features(native_secrets_management: true)
    enroll_instance_in_secrets_manager
  end

  shared_examples 'a query allowing read access to group secrets manager data' do
    it_behaves_like 'a working graphql query that returns data'

    it 'returns details about the secrets manager' do
      expect(graphql_data_at(:group_secrets_manager))
        .to match(
          a_graphql_entity_for(
            group: a_graphql_entity_for(group),
            status: 'PROVISIONING'
          )
        )
    end
  end

  context 'when current user is not part of the group' do
    before do
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is a guest' do
    before_all do
      group.add_guest(current_user)
    end

    before do
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query that returns a top-level access error'
  end

  context 'when current user is a reporter' do
    before_all do
      group.add_reporter(current_user)
    end

    before do
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query allowing read access to group secrets manager data'
  end

  context 'when current user is a developer' do
    before_all do
      group.add_developer(current_user)
    end

    before do
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query allowing read access to group secrets manager data'
  end

  context 'when current user is a maintainer' do
    before_all { group.add_maintainer(current_user) }

    before do
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query allowing read access to group secrets manager data'
  end

  context 'when current user is the group owner' do
    before_all do
      group.add_owner(current_user)
    end

    before do
      post_graphql(query, current_user: current_user)
    end

    it_behaves_like 'a query allowing read access to group secrets manager data'

    context 'and the secrets manager entitlement denies access' do
      # The SM status query is a "surface" permission that stays available
      # regardless of entitlement state, so callers can render an
      # entitlement-appropriate UI. Values and mutations are gated by other
      # abilities in the same entitlement-denies rule.
      before do
        stub_feature_flags(secrets_manager_paid_experience: true)
        allow(SecretsManagement::Entitlement).to receive(:for)
          .and_return(SecretsManagement::Entitlement.new(state: :ineligible))

        post_graphql(query, current_user: current_user)
      end

      it_behaves_like 'a query allowing read access to group secrets manager data'
    end
  end
end
