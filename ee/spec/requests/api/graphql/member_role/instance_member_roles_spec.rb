# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.instance_member_role', feature_category: :system_access do
  include GraphqlHelpers

  def member_roles_query
    <<~QUERY
    {
      memberRoles {
        nodes {
          id
          name
          membersCount
          editPath
        }
      }
    }
    QUERY
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:group_member_role) { create(:member_role, namespace: group, read_code: true) }

  let_it_be(:instance_role) { create(:member_role, :instance, read_vulnerability: true) }

  let_it_be(:user) { create(:user, owner_of: group) }
  let_it_be(:admin) { create(:admin) }

  subject(:roles) do
    graphql_data.dig('memberRoles', 'nodes')
  end

  context 'with custom roles feature', :enable_admin_mode do
    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'for an instance admin' do
      context 'when on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)

          post_graphql(member_roles_query, current_user: admin)
        end

        it 'raises an error' do
          expect { roles }.to raise_error { ArgumentError }
        end
      end

      context 'on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)

          post_graphql(member_roles_query, current_user: admin)
        end

        it_behaves_like 'a working graphql query'

        it 'returns only instance-level roles' do
          expected_result = [
            {
              'id' => instance_role.to_global_id.to_s,
              'name' => instance_role.name,
              'membersCount' => 0,
              'editPath' => edit_admin_application_settings_roles_and_permission_path(instance_role)
            }
          ]

          expect(roles).to match_array(expected_result)
        end
      end
    end

    context 'for a group owner' do
      context 'when on SaaS' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)

          post_graphql(member_roles_query, current_user: user)
        end

        it 'raises an error' do
          expect { roles }.to raise_error { ArgumentError }
        end
      end

      context 'when on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)

          post_graphql(member_roles_query, current_user: user)
        end

        it 'returns only instance-level roles' do
          expected_result = [
            {
              'id' => instance_role.to_global_id.to_s,
              'name' => instance_role.name,
              'membersCount' => 0,
              'editPath' => edit_admin_application_settings_roles_and_permission_path(instance_role)
            }
          ]

          expect(roles).to match_array(expected_result)
        end
      end
    end
  end

  context 'without custom roles feature', :enable_admin_mode do
    before do
      stub_licensed_features(custom_roles: false)

      post_graphql(member_roles_query, current_user: admin)
    end

    it 'returns an empty array' do
      expect(roles).to be_empty
    end
  end
end
