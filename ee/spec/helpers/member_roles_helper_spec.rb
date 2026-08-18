# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRolesHelper, feature_category: :permissions do
  include ApplicationHelper

  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:source) { build_stubbed(:group) }
  let_it_be(:root_group) { source.root_ancestor }

  before do
    stub_licensed_features(custom_roles: true)
    allow(helper).to receive(:current_user).and_return(user)
  end

  shared_examples 'no LDAP data' do
    it 'does not have LDAP servers data' do
      expect(data).not_to have_key(:ldap_servers)
    end

    it 'does not have LDAP users path' do
      expect(data).not_to have_key(:ldap_users_path)
    end
  end

  shared_examples 'does not have sign_in_restrictions_settings_path' do
    it { is_expected.not_to have_key(:sign_in_restrictions_settings_path) }
  end

  shared_examples 'has sign_in_restrictions_settings_path' do
    let_it_be(:expected_path) { '/admin/application_settings/general#js-signin-settings' }

    it { is_expected.to include(sign_in_restrictions_settings_path: expected_path) }
  end

  describe '#member_roles_data' do
    context 'when on self-managed' do
      subject(:data) { helper.member_roles_data }

      it_behaves_like 'no LDAP data'

      it 'matches the expected data' do
        expect(data[:new_role_path]).to be_nil
        expect(data[:group_full_path]).to be_nil
        expect(data[:group_id]).to be_nil
        expect(data[:current_user_email]).to eq user.notification_email_or_default
        expect(data[:is_saas]).to eq('false')
      end

      context 'with admin member role rights' do
        before do
          allow(helper).to receive(:can?).with(user, :admin_member_role).and_return(true)
          allow(helper).to receive(:can?).with(user, :create_ldap_admin_role_link).and_return(true)
          allow(Gitlab.config.ldap).to receive(:enabled).and_return(true)
        end

        it 'matches the expected data' do
          expect(data[:new_role_path]).to eq new_admin_application_settings_roles_and_permission_path
          expect(data[:group_full_path]).to be_nil
          expect(data[:group_id]).to be_nil
          expect(data[:current_user_email]).to eq user.notification_email_or_default
          expect(data[:ldap_servers]).to eq '[{"text":"ldap","value":"ldapmain"}]'
          expect(data[:ldap_users_path]).to eq '/admin/users?filter=ldap_sync'
        end

        context 'when license does not have custom roles feature' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it_behaves_like 'no LDAP data'
          it { is_expected.not_to have_key(:new_role_path) }
        end

        context 'when user cannot manage ldap admin links' do
          before do
            allow(helper).to receive(:can?).with(user, :create_ldap_admin_role_link).and_return(false)
          end

          it_behaves_like 'no LDAP data'
        end

        context 'when LDAP is not enabled for the instance' do
          before do
            allow(Gitlab.config.ldap).to receive(:enabled).and_return(false)
          end

          it_behaves_like 'no LDAP data'
        end

        context 'when all security recommendations are applied' do
          before do
            allow(Gitlab::CurrentSettings).to receive_messages(admin_mode: true,
              require_admin_two_factor_authentication: true)
            allow(MemberRole).to receive(:admin).and_return([build_stubbed(:member_role, :admin)])
            stub_licensed_features(custom_roles: true)
          end

          it_behaves_like 'does not have sign_in_restrictions_settings_path'

          context 'when admin mode is disabled' do
            before do
              allow(Gitlab::CurrentSettings).to receive(:admin_mode).and_return(false)
            end

            it_behaves_like 'has sign_in_restrictions_settings_path'
          end

          context 'when require administrators to enable 2FA is disabled' do
            before do
              allow(Gitlab::CurrentSettings).to receive(:require_admin_two_factor_authentication).and_return(false)
            end

            it_behaves_like 'has sign_in_restrictions_settings_path'
          end

          context 'when there are no admin member roles' do
            before do
              allow(MemberRole).to receive(:admin).and_return([])
            end

            it_behaves_like 'does not have sign_in_restrictions_settings_path'
          end

          context 'when the license does not have custom roles feature' do
            before do
              stub_licensed_features(custom_roles: false)
            end

            it_behaves_like 'does not have sign_in_restrictions_settings_path'
          end
        end
      end
    end

    context 'when on SaaS', :saas do
      context 'when on group page' do
        subject(:data) { helper.member_roles_data(source) }

        it_behaves_like 'no LDAP data'
        it_behaves_like 'does not have sign_in_restrictions_settings_path'

        it 'matches the expected data' do
          expect(data[:new_role_path]).to be_nil
          expect(data[:group_full_path]).to eq source.full_path
          expect(data[:group_id]).to eq source.id
          expect(data[:current_user_email]).to eq user.notification_email_or_default
          expect(data[:is_saas]).to eq('true')
        end

        context 'with admin member role rights' do
          before do
            allow(helper).to receive(:can?).with(user, :admin_member_role, root_group).and_return(true)
            allow(helper).to receive(:can?).with(user, :create_ldap_admin_role_link).and_return(true)
            allow(Gitlab.config.ldap).to receive(:enabled).and_return(true)
          end

          it_behaves_like 'does not have sign_in_restrictions_settings_path'

          it 'matches the expected data' do
            expect(data[:new_role_path]).to eq new_group_settings_roles_and_permission_path(source)
            expect(data[:group_full_path]).to eq source.full_path
            expect(data[:group_id]).to eq source.id
            expect(data[:current_user_email]).to eq user.notification_email_or_default
          end

          context 'when group license does not have custom roles features' do
            before do
              allow(root_group).to receive(:custom_roles_enabled?).and_return(false)
            end

            it { is_expected.not_to have_key(:new_role_path) }
          end
        end
      end
    end
  end

  describe '#manage_member_roles_path' do
    # Behavior is unit-tested in `ee/spec/models/members/manage_roles_path_spec.rb`.
    it 'delegates to Members::ManageRolesPath' do
      expect(::Members::ManageRolesPath).to receive(:for).with(source, user).and_return('/path')

      expect(helper.manage_member_roles_path(source)).to eq('/path')
    end
  end

  describe '#member_role_edit_path' do
    let_it_be(:regular_role) { build_stubbed(:member_role, id: 5, namespace: root_group) }
    let_it_be(:admin_role) { build_stubbed(:member_role, :admin, id: 5) }
    let_it_be(:standard_role) do
      role_string = +'GUEST'
      group = root_group
      role_string.define_singleton_method(:namespace) { group }
      role_string
    end

    let(:role) { regular_role }

    subject { helper.member_role_edit_path(role) }

    context 'when on self-managed' do
      context 'for regular custom role' do
        it { is_expected.to eq(edit_admin_application_settings_roles_and_permission_path(role)) }
      end

      context 'for admin custom role' do
        let(:role) { admin_role }

        it { is_expected.to eq(edit_admin_application_settings_roles_and_permission_path(role)) }
      end

      context 'for static role' do
        let(:role) { standard_role }

        it { is_expected.to eq(edit_admin_application_settings_roles_and_permission_path(role)) }
      end
    end

    context 'when on Saas', :saas do
      context 'for regular custom role' do
        it { is_expected.to eq(edit_group_settings_roles_and_permission_path(source, role)) }
      end

      context 'for admin custom role' do
        let(:role) { admin_role }

        it { is_expected.to eq(edit_admin_application_settings_roles_and_permission_path(role)) }
      end

      context 'for static role' do
        let(:role) { standard_role }

        it { is_expected.to eq(edit_group_settings_roles_and_permission_path(source, role)) }
      end
    end
  end

  describe '#member_role_details_path' do
    subject(:role_path) { helper.member_role_details_path(role) }

    let_it_be(:regular_role) { build_stubbed(:member_role, id: 5, namespace: root_group) }
    let_it_be(:admin_role) { build_stubbed(:member_role, :admin, id: 5, namespace: source) }
    let_it_be(:standard_role) do
      role_string = +'GUEST'
      group = root_group
      role_string.define_singleton_method(:namespace) { group }
      role_string
    end

    let(:role) { regular_role }

    context 'when on self-managed' do
      context 'for regular custom role' do
        it { is_expected.to eq(admin_application_settings_roles_and_permission_path(role)) }
      end

      context 'for admin custom role' do
        let(:role) { admin_role }

        it { is_expected.to eq(admin_application_settings_roles_and_permission_path(role)) }
      end

      context 'for static role' do
        let(:role) { standard_role }

        it { is_expected.to eq(admin_application_settings_roles_and_permission_path(role)) }
      end
    end

    context 'when on Saas', :saas do
      context 'for regular custom role' do
        it { is_expected.to eq(group_settings_roles_and_permission_path(root_group, role)) }
      end

      context 'for admin custom role' do
        let(:role) { admin_role }

        it { is_expected.to eq(admin_application_settings_roles_and_permission_path(role)) }
      end

      context 'for static role' do
        let(:role) { standard_role }

        it { is_expected.to eq(group_settings_roles_and_permission_path(root_group, role)) }
      end
    end
  end
end
