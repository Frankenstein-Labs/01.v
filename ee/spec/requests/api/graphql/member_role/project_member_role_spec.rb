# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project_member_role', feature_category: :system_access do
  include GraphqlHelpers

  let(:member_roles_query) do
    <<~QUERY
    query {
      project(fullPath: "#{project.full_path}") {
        id
        name
        memberRoles {
          nodes {
            id
            name
          }
        }
      }
    }
    QUERY
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:group_member_role_1) { create(:member_role, namespace: group, read_code: true) }
  let_it_be(:group_member_role_2) { create(:member_role, namespace: group, read_vulnerability: true) }
  let_it_be(:group_2_member_role) { create(:member_role) }

  let_it_be(:group_owner) { create(:user, owner_of: group) }

  let(:user) { group_owner }

  subject do
    graphql_data.dig('project', 'memberRoles', 'nodes')
  end

  shared_examples 'returning group member roles' do
    it_behaves_like 'a working graphql query'

    it 'returns all group-level member roles' do
      subject

      expected_result = [
        { 'id' => group_member_role_1.to_global_id.to_s, 'name' => group_member_role_1.name },
        { 'id' => group_member_role_2.to_global_id.to_s, 'name' => group_member_role_2.name }
      ]

      expect(subject).to match_array(expected_result)
    end
  end

  context 'with custom roles feature' do
    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when on SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)

        post_graphql(member_roles_query, current_user: user)
      end

      it_behaves_like 'returning group member roles'

      context 'when user is a member only in project' do
        let_it_be(:project_owner) { create(:user, owner_of: project) }

        let(:user) { project_owner }

        it_behaves_like 'returning group member roles'
      end

      context 'when user is a not a project or group member' do
        let_it_be(:other_user) { create(:user) }

        let(:user) { other_user }

        it 'does not return any member roles' do
          expect(subject).to be_nil
        end
      end
    end

    context 'when on self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)

        post_graphql(member_roles_query, current_user: user)
      end

      it_behaves_like 'a working graphql query'

      it 'returns an empty array' do
        expect(subject).to be_empty
      end
    end
  end

  context 'without custom roles feature' do
    before do
      stub_licensed_features(custom_roles: false)

      post_graphql(member_roles_query)
    end

    it 'does not return any member roles' do
      expect(subject).to be_nil
    end
  end
end
