# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::RolesAndPermissionsController, feature_category: :user_management do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:admin) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:member_role) { create(:member_role, namespace: group) }
  let_it_be(:role_id) { member_role.id }

  before do
    stub_saas_features(gitlab_com_subscriptions: true)
  end

  shared_examples 'page is not found' do
    it 'has correct status' do
      get_method

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'access control' do |licenses|
    shared_examples 'page is found under proper conditions' do
      it 'returns a 200 status code' do
        get_method

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when accessing a subgroup' do
        let_it_be(:group) { create(:group, parent: group) }

        it_behaves_like 'page is not found'
      end

      context 'when license is disabled' do
        before do
          stub_licensed_features(license => false)
        end

        it_behaves_like 'page is not found'
      end
    end

    where(license: licenses)

    with_them do
      before do
        stub_licensed_features(license => true)
      end

      context 'when not logged in' do
        it_behaves_like 'page is not found'
      end

      context 'with different access levels not allowed' do
        where(access_level: [nil, :guest, :reporter, :developer, :maintainer])

        with_them do
          before do
            group.add_member(user, access_level)
            sign_in(user)
          end

          it_behaves_like 'page is not found'
        end
      end

      context 'with admins' do
        before do
          sign_in(admin)
          enable_admin_mode!(admin)
        end

        it_behaves_like 'page is found under proper conditions'

        context 'on self-managed' do
          before do
            stub_saas_features(gitlab_com_subscriptions: false)
          end

          it_behaves_like 'page is not found'
        end
      end

      context 'with group owners' do
        before do
          group.add_member(user, :owner)
          sign_in(user)
        end

        it_behaves_like 'page is found under proper conditions'
      end

      context 'with ldap synced group owner' do
        let_it_be(:group_link) { create(:ldap_group_link, group: group, group_access: Gitlab::Access::OWNER) }
        let_it_be(:group_member) { create(:group_member, :owner, :ldap, :active, user: user, source: group) }

        before do
          stub_application_setting(lock_memberships_to_ldap: true)
          sign_in(user)
        end

        it_behaves_like 'page is found under proper conditions'
      end
    end
  end

  shared_examples 'role existence check' do
    before do
      group.add_member(user, :owner)
      sign_in(user)
      stub_licensed_features(custom_roles: true)
    end

    context 'with a valid custom role' do
      it 'returns a 200 status code' do
        get_method

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when the ID is for a non-existent custom role' do
      let_it_be(:role_id) { non_existing_record_id }

      it_behaves_like 'page is not found'
    end

    context 'when the ID is for a non-existent standard role' do
      let_it_be(:role_id) { 'NONEXISTENT_ROLE' }

      it_behaves_like 'page is not found'
    end

    context 'when the ID is for the minimal access role' do
      let_it_be(:role_id) { 'MINIMAL_ACCESS' }

      it_behaves_like 'page is not found'
    end
  end

  describe 'GET #index', :saas do
    subject(:get_method) { get(group_settings_roles_and_permissions_path(group)) }

    it_behaves_like 'access control', [:custom_roles, :default_roles_assignees]
  end

  describe 'GET #show', :saas do
    subject(:get_method) { get(group_settings_roles_and_permission_path(group, role_id)) }

    it_behaves_like 'access control', [:custom_roles]
    it_behaves_like 'role existence check'
  end

  describe 'GET #show for default_roles_assignees license', :saas do
    subject(:get_method) { get group_settings_roles_and_permission_path(group, 'GUEST') }

    it_behaves_like 'access control', [:default_roles_assignees]
  end

  describe 'GET #edit', :saas do
    subject(:get_method) { get(edit_group_settings_roles_and_permission_path(group, role_id)) }

    it_behaves_like 'access control', [:custom_roles]
    it_behaves_like 'role existence check'
  end
end
