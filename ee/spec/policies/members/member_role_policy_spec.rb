# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::MemberRolePolicy, feature_category: :system_access do
  using RSpec::Parameterized::TableSyntax
  include AdminModeHelper

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:instance_member_role) { create(:member_role, :instance) }
  let_it_be(:group_member_role) { create(:member_role, namespace: group) }

  let(:member_role) { group_member_role }

  subject(:policy) { described_class.new(user, member_role) }

  shared_examples 'correct member role permissions' do
    let(:special_roles) { [:admin, :non_member, :auditor] }

    before do
      group.public_send(:"add_#{role}", user) unless special_roles.include?(role)

      if role == :admin
        user.update!(admin: true)
        enable_admin_mode!(user)
      elsif role == :auditor
        user.update!(auditor: true)
      end
    end

    context 'when custom_roles feature is enabled' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'for instance-level custom role' do
        let(:member_role) { instance_member_role }

        context 'for logged-in users' do
          it 'returns correct value' do
            is_expected.to(instance_role_allowed ? be_allowed(permission) : be_disallowed(permission))
          end
        end

        context 'when memberships are locked to LDAP' do
          before do
            allow(group).to receive(:ldap_synced?).and_return(true)
            stub_application_setting(allow_group_owners_to_manage_ldap: true)
            stub_application_setting(lock_memberships_to_ldap: true)
          end

          it 'returns correct value' do
            is_expected.to(instance_role_allowed ? be_allowed(permission) : be_disallowed(permission))
          end
        end
      end

      context 'for group-level custom role' do
        let(:member_role) { group_member_role }

        context 'for SaaS' do
          it { is_expected.to(group_role_allowed ? be_allowed(permission) : be_disallowed(permission)) }

          context 'when memberships are locked to LDAP' do
            before do
              allow(group).to receive(:ldap_synced?).and_return(true)
              stub_application_setting(allow_group_owners_to_manage_ldap: true)
              stub_application_setting(lock_memberships_to_ldap: true)
            end

            it { is_expected.to(group_role_allowed ? be_allowed(permission) : be_disallowed(permission)) }
          end
        end
      end
    end

    context 'when custom_roles feature is disabled' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it { is_expected.to be_disallowed(permission) }
    end
  end

  describe 'rules' do
    describe ':read_member_role' do
      using RSpec::Parameterized::TableSyntax

      let(:permission) { :read_member_role }

      where(:role, :instance_role_allowed, :group_role_allowed) do
        :non_member | true  | false
        :guest      | true  | true
        :reporter   | true  | true
        :developer  | true  | true
        :maintainer | true  | true
        :auditor    | true  | false
        :owner      | true  | true
        :admin      | true  | true
      end

      with_them do
        it_behaves_like 'correct member role permissions'
      end

      context 'for anonymous user' do
        subject(:policy) { described_class.new(nil, member_role) }

        context 'for group roles' do
          let(:member_role) { group_member_role }

          it 'returns false' do
            is_expected.to be_disallowed(:read_member_role)
          end
        end

        context 'for instnace roles' do
          let(:member_role) { instance_member_role }

          it 'returns false' do
            is_expected.to be_disallowed(:read_member_role)
          end
        end
      end
    end

    describe ':admin_member_role' do
      let(:permission) { :admin_member_role }

      context 'for Saas', :saas do
        using RSpec::Parameterized::TableSyntax

        where(:role, :instance_role_allowed, :group_role_allowed) do
          :non_member | false | false
          :guest      | false | false
          :reporter   | false | false
          :developer  | false | false
          :maintainer | false | false
          :auditor    | false | false
          :owner      | false | true
          :admin      | true | true
        end

        with_them do
          it_behaves_like 'correct member role permissions'
        end
      end

      context 'for self-managed' do
        it { is_expected.to be_disallowed(permission) }
      end
    end
  end

  describe 'admin role permissions' do
    let_it_be(:current_user) { user }
    let_it_be(:admin) { build(:admin) }

    subject(:policy) { described_class.new(current_user, member_role) }

    where(:permission, :license) do
      :read_admin_role    | :custom_roles
      :update_admin_role  | :custom_roles
      :delete_admin_role  | :custom_roles
    end

    include_examples 'permission is allowed/disallowed with feature flags toggled'
  end
end
