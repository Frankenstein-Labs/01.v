# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::ServiceAccountsController, feature_category: :user_management do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:admin) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:role_id) { Gitlab::Access.options.each_key.first }

  shared_examples 'page is not found' do
    it 'has correct status' do
      get_method

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'page is found' do
    it 'returns a 200 status code' do
      get_method

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  shared_examples 'access control' do |licenses|
    shared_examples 'page is found under proper conditions' do
      it_behaves_like 'page is found'

      context 'on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it_behaves_like 'page is found'
      end

      context 'when in SaaS mode', :saas do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        it_behaves_like 'page is found'
      end

      context 'when accessing a subgroup' do
        let_it_be(:group) { create(:group, parent: group) }

        it_behaves_like 'page is found'
      end
    end

    where(license: licenses)

    with_them do
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

  describe 'GET #index' do
    subject(:get_method) { get(group_settings_service_accounts_path(group)) }

    before do
      stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
    end

    it_behaves_like 'access control', [:default_roles_assignees]
  end
end
