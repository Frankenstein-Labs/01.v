# frozen_string_literal: true

require "spec_helper"

RSpec.describe Groups::GroupMembersHelper, feature_category: :groups_and_projects do
  include MembersPresentation
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(current_user)
  end

  subject(:helper_app_data) do
    helper.group_members_app_data(
      group,
      members: [],
      invited: [],
      access_requests: [],
      banned: banned,
      include_relations: [:inherited, :direct],
      pending_members_count: nil,
      placeholder_users: {}
    )
  end

  describe '#group_members_app_data' do
    let(:banned) { [] }

    before do
      allow(helper).to receive(:override_group_group_member_path).with(group, ':id').and_return('/groups/foo-bar/-/group_members/:id/override')
      allow(helper).to receive(:group_group_member_path).with(group, ':id').and_return('/groups/foo-bar/-/group_members/:id')
      allow(helper).to receive(:manage_member_roles_path).with(group).and_return(admin_application_settings_roles_and_permissions_path)
      allow(helper).to receive(:can?).with(current_user, :admin_group_member, group).and_return(true)
      allow(helper).to receive(:can?).with(current_user, :admin_member_access_request, group).and_return(true)
      allow(helper).to receive(:can?).with(current_user, :export_group_memberships, group).and_return(true)
    end

    it 'adds `ldap_override_path`' do
      expect(subject[:user][:ldap_override_path]).to eq('/groups/foo-bar/-/group_members/:id/override')
    end

    it 'adds `can_export_members`' do
      expect(subject[:can_export_members]).to be true
    end

    it 'adds `export_csv_path`' do
      expect(subject[:export_csv_path]).not_to be_nil
    end

    it 'adds `manage_member_roles_path`' do
      expect(subject[:manage_member_roles_path]).to eq(admin_application_settings_roles_and_permissions_path)
    end

    context 'when domain verification is available' do
      before do
        stub_licensed_features(domain_verification: true)
        allow(::Gitlab).to receive(:com?).and_return(true)
      end

      context 'when enterprise users exist for the group' do
        let_it_be(:enterprise_user) { create(:user, enterprise_group: group) }

        it 'sets the restrict_reassignment_to_enterprise flag to true' do
          expect(subject[:restrict_reassignment_to_enterprise]).to be(true)
        end
      end

      context 'when enterprise users do not exist for the group' do
        it 'sets the restrict_reassignment_to_enterprise flag to false' do
          expect(subject[:restrict_reassignment_to_enterprise]).to be(false)
        end
      end
    end

    context 'adds `can_approve_access_requests`' do
      before do
        stub_ee_application_setting(dashboard_limit_enabled: true)

        allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement, group.root_ancestor) do |instance|
          allow(instance).to receive(:enforce_cap?).and_return(true)
        end
      end

      context 'when namespace has reached the user limit (can not approve accesss requests)' do
        before do
          stub_ee_application_setting(dashboard_limit: 0)
        end

        it 'sets the value to false' do
          expect(subject[:can_approve_access_requests]).to be(false)
        end
      end

      context 'when namespace has not reached the user limit (can approve access requests)' do
        before do
          stub_ee_application_setting(dashboard_limit: 5)

          allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement, group.root_ancestor) do |instance|
            allow(instance).to receive(:enforce_cap?).and_return(true)
          end
        end

        it 'sets the value to true' do
          expect(subject[:can_approve_access_requests]).to be(true)
        end
      end
    end

    context 'adds `namespace_user_limit`' do
      context 'when dashboard limit is set' do
        before do
          stub_ee_application_setting(dashboard_limit: 5)
        end

        it 'sets the value to false' do
          expect(subject[:namespace_user_limit]).to eq(5)
        end
      end

      context 'when dashboard limit is not set' do
        it 'sets the value to false' do
          expect(subject[:namespace_user_limit]).to eq(0)
        end
      end
    end

    describe '`can_filter_by_enterprise`', :saas do
      where(:domain_verification_availabe_for_group, :can_admin_group_member, :expected_value) do
        true  | true  | true
        true  | false | false
        false | true  | false
        false | false | false
      end

      with_them do
        before do
          stub_licensed_features(domain_verification: domain_verification_availabe_for_group)
          allow(helper).to receive(:can?).with(current_user, :admin_group_member, group).and_return(can_admin_group_member)
        end

        it "is set to #{params[:expected_value]}" do
          expect(subject[:can_filter_by_enterprise]).to eq(expected_value)
        end
      end
    end

    describe 'allow enterprise user confirmation bypass', :saas do
      context 'when domain verification is unavailable' do
        before do
          stub_licensed_features(domain_verification: false)
          group.namespace_settings.allow_enterprise_bypass_placeholder_confirmation = true
        end

        it 'returns false' do
          expect(helper.allow_group_owner_enterprise_bypass?(group)).to be_falsey
        end
      end

      context 'when group owner bypass setting is false' do
        before do
          group.namespace_settings.allow_enterprise_bypass_placeholder_confirmation = false
        end

        it 'returns false' do
          expect(helper.allow_group_owner_enterprise_bypass?(group)).to be_falsey
        end
      end

      context 'when all conditions are met' do
        before do
          stub_licensed_features(domain_verification: true)
          group.namespace_settings.allow_enterprise_bypass_placeholder_confirmation = true
        end

        it 'returns true' do
          expect(helper.allow_group_owner_enterprise_bypass?(group)).to be_truthy
        end
      end
    end

    context 'banned members' do
      let(:banned) { present_members(create_list(:group_member, 2, group: group, created_by: current_user)) }

      it 'returns `members` property that matches json schema' do
        expect(subject[:banned][:members].to_json).to match_schema('members')
      end

      it 'sets `member_path` property' do
        expect(subject[:banned][:member_path]).to eq('/groups/foo-bar/-/group_members/:id')
      end
    end

    context 'with promotion_request feature' do
      let(:type) { :for_group_member }
      let(:member_namespace) { group }

      subject(:helper_app_data) do
        helper.group_members_app_data(
          group,
          members: [],
          invited: [],
          access_requests: [],
          banned: banned,
          include_relations: [:inherited, :direct],
          pending_members_count: pending_members_count,
          placeholder_users: {}
        )
      end

      it_behaves_like 'adding promotion_request in app data'
    end

    describe 'available roles' do
      subject(:available_roles) { helper_app_data[:available_roles] }

      context 'when group allows minimal access members' do
        before do
          stub_licensed_features(minimal_access_role: true)
        end

        let(:minimal_access) { EE::Gitlab::Access::MINIMAL_ACCESS_HASH }

        it { is_expected.to include(title: minimal_access.keys[0], value: "static-#{minimal_access.values[0]}") }
      end

      context 'when custom roles exist' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        let!(:member_role) { create(:member_role, :instance) }

        it { is_expected.to include(title: member_role.name, value: "custom-#{member_role.id}") }
      end
    end
  end

  describe '#group_member_header_subtext' do
    let(:base_subtext) { "You&#39;re viewing members of <strong>#{group.name}</strong>." }
    let(:cannot_invite_subtext_for_com) do
      "You cannot invite a new member to <strong>#{group.name}</strong>. " \
        "User invitations are disabled by the group owner."
    end

    let(:cannot_invite_subtext_for_self_managed) do
      "You cannot invite a new member to <strong>#{group.name}</strong>. " \
        "User invitations are disabled by the instance administrator."
    end

    let(:standard_subtext) { "^#{base_subtext}$" }
    let(:enforcement_subtext) { "^#{base_subtext}<br />To manage seats for all members" }

    where(:com, :can_invite_member, :can_admin_member, :enforce_free_user_cap, :subtext) do
      true | true | true | true | ref(:enforcement_subtext)
      true | false | true | true | ref(:cannot_invite_subtext_for_com)
      false | false | true | true | ref(:cannot_invite_subtext_for_self_managed)

      true | true | true | false | ref(:standard_subtext)
      true | false | true  | false | ref(:cannot_invite_subtext_for_com)
      false | false | true | false | ref(:cannot_invite_subtext_for_self_managed)

      true | true | false | true | ref(:standard_subtext)
      true | false | false | true  | ref(:cannot_invite_subtext_for_com)
      false | false | false | true | ref(:cannot_invite_subtext_for_self_managed)

      true | true | false | false | ref(:standard_subtext)
      true | false | false | false | ref(:cannot_invite_subtext_for_com)
      false | false | false | false | ref(:cannot_invite_subtext_for_self_managed)
    end

    before do
      allow(helper).to receive(:can?).with(current_user, :invite_group_members, group)
                                    .and_return(can_invite_member)
      allow(Gitlab::Saas).to receive(:feature_available?).with(:group_disable_invite_members).and_return(com)

      if can_invite_member
        allow(helper).to receive(:can?).with(current_user, :admin_group_member, group).and_return(can_admin_member)
      end

      allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement, group) do |instance|
        allow(instance).to receive(:enforce_cap?).and_return(enforce_free_user_cap)
      end
    end

    with_them do
      it 'contains expected text' do
        expect(helper.group_member_header_subtext(group)).to match(subtext)
      end
    end
  end

  context 'when member has custom role' do
    let(:member_role) { create(:member_role, :guest, name: 'guest plus', namespace: group, read_code: true, description: 'My custom role') }
    let(:user) { create(:user) }
    let(:banned) { present_members(create_list(:group_member, 1, :guest, group: group, user: user, member_role: member_role)) }

    it 'returns `members` property that matches json schema' do
      expect(subject[:banned][:members].to_json).to match_schema('members')
    end
  end
end
