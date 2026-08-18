# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::MemberRole, feature_category: :system_access do
  using RSpec::Parameterized::TableSyntax

  it "includes the AdminRollable Concern" do
    expect(described_class.included_modules).to include(Authz::AdminRollable)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to have_many(:members) }
    it { is_expected.to have_many(:saml_providers) }
    it { is_expected.to have_many(:saml_group_links) }
    it { is_expected.to have_many(:group_group_links) }
    it { is_expected.to have_many(:user_member_roles) }
    it { is_expected.to have_many(:ldap_admin_role_links) }
    it { is_expected.to have_many(:protected_branch_merge_access_levels).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:protected_branch_push_access_levels).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:protected_branch_unprotect_access_levels).dependent(:restrict_with_error) }
  end

  describe 'validation' do
    subject(:member_role) { build(:member_role) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:base_access_level) }

    it do
      is_expected.to validate_inclusion_of(:base_access_level)
        .in_array(::Gitlab::Access.options_for_custom_roles.values.freeze)
    end

    context 'for sharding key' do
      it 'validates that namespace and organization both cannot be present' do
        member_role = build(:member_role, namespace: build(:namespace), organization: build(:organization))

        expect(member_role).not_to be_valid
        expect(member_role.errors[:base]).to include('A sharding key (namespace_id or organization_id) is required')
      end

      it 'validates that namespace and organization cannot be blank' do
        member_role = build(:member_role, namespace: nil, organization: nil)

        expect(member_role).not_to be_valid
        expect(member_role.errors[:base]).to include('A sharding key (namespace_id or organization_id) is required')
      end
    end

    context 'for name uniqueness' do
      let_it_be(:group, freeze: false) { create(:group) }
      let_it_be(:existing_member_role, freeze: false) { create(:member_role, name: 'foo', namespace: group) }

      context 'when creating a new record' do
        it 'is invalid when the name already exists in the namespace' do
          member_role = build(:member_role, name: 'foo', namespace: group)

          expect(member_role).not_to be_valid
          expect(member_role.errors[:name]).to include('has already been taken')
        end

        it 'is valid when the name exists in a different namespace' do
          member_role = build(:member_role, name: 'foo', namespace: create(:namespace))

          expect(member_role).to be_valid
        end

        it 'is invalid when creating a duplicate name at the instance level' do
          create(:member_role, :instance, name: 'foo')
          member_role = build(:member_role, :instance, name: 'foo')

          expect(member_role).not_to be_valid
        end

        context 'with nil base_access_level' do
          where(:admin_ability) { MemberRole.all_customizable_admin_permission_keys }

          with_them do
            context "when admin ability #{params[:admin_ability]} is enabled" do
              let(:admin_role) { build(:member_role, admin_ability) }

              it "is valid" do
                expect(admin_role.base_access_level).to be_nil
                expect(admin_role).to be_valid
              end
            end
          end
        end
      end

      context 'when updating an old record' do
        it 'is invalid when the name already exists in the namespace' do
          member_role = create(:member_role, name: 'foo 2', namespace: group)
          member_role.name = 'foo'

          expect(member_role).not_to be_valid
        end
      end
    end

    context 'for namespace presence' do
      context 'when running on Gitlab.com', :saas do
        context 'with a regular role' do
          it { is_expected.to validate_presence_of(:namespace) }
        end

        context 'with an admin role' do
          subject(:member_role) { build(:member_role, :admin) }

          it { is_expected.not_to validate_presence_of(:namespace) }
        end
      end

      context 'when running on self-managed' do
        it { is_expected.to be_valid }
      end

      context 'when creating an admin role' do
        subject(:member_role) { build(:member_role, :admin) }

        it { is_expected.to validate_absence_of(:namespace) }

        context 'when admin permissions are disabled' do
          subject(:member_role) { build(:member_role, read_admin_users: false) }

          it { is_expected.not_to validate_absence_of(:namespace) }
        end
      end
    end

    context 'for permissions' do
      it 'removes disabled permissions' do
        member_role = build(:member_role, :guest, :read_code)
        member_role.permissions["nonexistent"] = false

        expect { member_role.validate }.to change { member_role.permissions }.from(
          { 'read_code' => true, 'nonexistent' => false }
        ).to({ 'read_code' => true })
      end

      it 'returns an error for admin permissions' do
        member_role = build(:member_role, :guest, :read_code)
        member_role.permissions["read_admin_users"] = true

        member_role.validate
        expect(member_role.errors.first.message).to eq('Unknown permission: read_admin_users')
      end
    end

    context 'for json schema' do
      let(:permissions) { { read_code: true } }

      it { is_expected.to allow_value(permissions).for(:permissions) }

      context 'when trying to store an unsupported value' do
        let(:permissions) { { read_code: 'some_value' } }

        it { is_expected.not_to allow_value(permissions).for(:permissions) }
      end
    end

    context 'for base_access_level_locked' do
      before do
        member_role.base_access_level = ProjectMember::GUEST
        member_role.read_vulnerability = true
        member_role.save!

        member_role.read_vulnerability = false
        member_role.name = 'new name'
        member_role.description = 'new description'
      end

      it 'cannot be saved when base_access_level has changes' do
        member_role.base_access_level = ProjectMember::DEVELOPER

        expect(member_role).not_to be_valid
        expect(member_role.errors.messages[:base_access_level]).to include(
          s_('MemberRole|cannot be changed. Please create a new Member Role instead.')
        )
      end

      it 'can be changed when only name, description and permissions change' do
        expect(member_role).to be_valid
      end
    end

    context 'when not assigned to member' do
      it 'can be changed' do
        expect(member_role).to be_valid
      end
    end

    context 'for max_count_per_group_hierarchy' do
      let_it_be(:group, freeze: false) { create(:group) }

      subject(:member_role) { build(:member_role, namespace: group) }

      context 'when number of member roles is below limit' do
        it 'is valid' do
          is_expected.to be_valid
        end
      end

      context 'when number of member roles is above limit' do
        before do
          stub_const('MemberRole::MAX_COUNT_PER_GROUP_HIERARCHY', 1)
          create(:member_role, namespace: group)
          group.reload
        end

        it 'is invalid' do
          is_expected.to be_invalid
        end
      end
    end

    context 'when for namespace' do
      let_it_be(:root_group, freeze: false) { create(:group) }

      context 'when namespace is a subgroup' do
        it 'is invalid' do
          subgroup = create(:group, parent: root_group)
          member_role.namespace = subgroup

          expect(member_role).to be_invalid
          expect(member_role.errors[:namespace]).to include(
            s_("MemberRole|must be top-level namespace")
          )
        end
      end

      context 'when namespace is a root group' do
        it 'is valid' do
          member_role.namespace = root_group

          expect(member_role).to be_valid
        end
      end

      context 'when namespace is outside hierarchy of member' do
        it 'creates a validation error' do
          member_role.save!
          member_role.namespace = create(:group)

          expect(member_role).not_to be_valid
          expect(member_role.errors[:namespace]).to include(s_("MemberRole|can't be changed"))
        end
      end

      context 'when base_access_level is invalid' do
        it 'raises an error' do
          member_role.base_access_level = 11

          expect(member_role).not_to be_valid
          expect(member_role.errors[:base_access_level])
            .to include("is not included in the list")
        end
      end

      context 'when requirement is not met' do
        it 'creates a validation error' do
          member_role.base_access_level = Gitlab::Access::GUEST
          member_role.read_vulnerability = false
          member_role.admin_vulnerability = true

          expect(member_role).not_to be_valid
          expect(member_role.errors[:base])
            .to include(s_("MemberRole|Read vulnerability has to be enabled in order to enable Admin vulnerability"))
        end
      end

      context 'when requirement is met via base access level' do
        it 'is valid' do
          member_role.base_access_level = Gitlab::Access::REPORTER
          member_role.read_vulnerability = true
          member_role.admin_vulnerability = true

          expect(member_role).to be_valid
        end
      end

      describe 'enabled for access levels' do
        let(:project_levels) { [30, 40, 50] }
        let(:group_levels) { [30, 40, 50] }

        before do
          allow(described_class).to receive(:all_customizable_permissions).and_return(
            admin_vulnerability: {
              requirements: ['read_vulnerability']
            },
            read_vulnerability: {
              enabled_for_project_access_levels: project_levels,
              enabled_for_group_access_levels: group_levels
            }.compact
          )

          member_role.base_access_level = Gitlab::Access::DEVELOPER
          member_role.admin_vulnerability = true
        end

        context 'when group and project access levels are configured' do
          it 'is valid' do
            expect(member_role).to be_valid
          end
        end

        context 'when only project access levels are configured' do
          let(:group_levels) { nil }

          it 'is valid' do
            expect(member_role).to be_valid
          end
        end

        context 'when only group access levels are configured' do
          let(:project_levels) { nil }

          it 'is valid' do
            expect(member_role).to be_valid
          end
        end

        context 'when neither project nor group access levels are configured' do
          let(:project_levels) { nil }
          let(:group_levels) { nil }

          it 'is invalid' do
            expect(member_role).not_to be_valid
          end
        end
      end
    end
  end

  describe 'callbacks' do
    context 'for preventing deletion after member is associated' do
      let_it_be_with_reload(:member_role) { create(:member_role) }

      subject(:destroy_member_role) { member_role.destroy } # rubocop: disable Rails/SaveBang

      it 'allows deletion without any member associated' do
        expect(destroy_member_role).to be_truthy
      end

      it 'prevents deletion when member is associated' do
        create(:group_member, { group: member_role.namespace,
                                access_level: Gitlab::Access::DEVELOPER,
                                member_role: member_role })
        member_role.members.reload

        expect(destroy_member_role).to be_falsey
        expect(member_role.errors.messages[:base])
          .to(
            include(s_(
              "MemberRole|Role is assigned to one or more group members. " \
              "Remove role from all group members, then delete role."
            ))
          )
      end
    end

    context 'for preventing deletion after admin is associated' do
      let_it_be_with_reload(:member_role) { create(:member_role, :read_admin_users) }

      subject(:destroy_admin_member_role) { member_role.destroy } # rubocop: disable Rails/SaveBang

      it 'allows deletion without any admin associated' do
        expect(destroy_admin_member_role).to be_truthy
      end

      it 'prevents deletion when admin is associated' do
        create(:user_member_role, member_role: member_role)

        member_role.user_member_roles.reload

        expect(destroy_admin_member_role).to be_falsey
        expect(member_role.errors.messages[:base]).to(include(
          s_('MemberRole|Admin role is assigned to one or more users. Remove role from all users, then delete role.')
        ))
      end
    end

    context 'for preventing deletion when protected branch access level is associated' do
      let_it_be_with_reload(:member_role) { create(:member_role) }

      subject(:destroy_member_role) { member_role.destroy } # rubocop: disable Rails/SaveBang

      before do
        stub_licensed_features(custom_roles: true)
        stub_feature_flags(custom_roles_for_protected_branches: true)
      end

      it 'allows deletion without any access level associated' do
        expect(destroy_member_role).to be_truthy
      end

      it 'prevents deletion when push access level is associated' do
        protected_branch = create(:protected_branch, project: nil, group: member_role.namespace)
        create(:protected_branch_push_access_level, protected_branch: protected_branch, member_role: member_role)

        expect(destroy_member_role).to be_falsey
        expect(member_role.errors.full_messages).not_to be_empty
      end

      it 'prevents deletion when merge access level is associated' do
        protected_branch = create(:protected_branch, project: nil, group: member_role.namespace)
        create(:protected_branch_merge_access_level, protected_branch: protected_branch, member_role: member_role)

        expect(destroy_member_role).to be_falsey
        expect(member_role.errors.full_messages).not_to be_empty
      end

      it 'prevents deletion when unprotect access level is associated' do
        protected_branch = create(:protected_branch, project: nil, group: member_role.namespace)
        create(:protected_branch_unprotect_access_level, protected_branch: protected_branch, member_role: member_role)

        expect(destroy_member_role).to be_falsey
        expect(member_role.errors.full_messages).not_to be_empty
      end
    end

    context 'for preventing deletion after ldap role link is associated' do
      let_it_be_with_reload(:member_role) { create(:member_role, :read_admin_users) }

      subject(:destroy_admin_member_role) { member_role.destroy } # rubocop: disable Rails/SaveBang

      it 'allows deletion without any ldap role links associated' do
        expect(destroy_admin_member_role).to be_truthy
      end

      it 'prevents deletion when ldap role link is associated' do
        create(:ldap_admin_role_link, member_role: member_role)

        member_role.user_member_roles.reload

        expect(destroy_admin_member_role).to be_falsey
        expect(member_role.errors.messages[:base]).to(include(
          s_('MemberRole|Admin role is used by one or more LDAP synchronizations. Remove LDAP syncs, then delete role.')
        ))
      end
    end
  end

  describe 'scopes' do
    let_it_be(:group, freeze: false) { create(:group) }
    let_it_be(:member_role_1, freeze: false) { create(:member_role, :guest, name: 'Tester', namespace: group) }
    let_it_be(:member_role_2, freeze: false) { create(:member_role, :guest, name: 'Manager', namespace: group) }
    let_it_be(:admin_member_role, freeze: false) { create(:member_role, :admin) }
    let_it_be(:group_2_member_role, freeze: false) { create(:member_role, :guest, name: 'Actor') }

    describe '.elevating' do
      it 'creates proper query' do
        allow(described_class).to receive(:all_customizable_permissions).and_return(
          read_code: { description: 'Permission to read code', skip_seat_consumption: true },
          see_code: { description: 'Test permission' }
        )

        expect(described_class.elevating.to_sql)
          .to include("member_roles.permissions @> ('{\"see_code\":true}')::jsonb")
      end

      it 'creates proper query with multiple permissions' do
        allow(described_class).to receive(:all_customizable_permissions).and_return(
          read_code: { description: 'Permission to read code', skip_seat_consumption: true },
          see_code: { description: 'Test permission', skip_seat_consumption: false },
          remove_code: { description: 'Test second permission' }
        )

        expected_sql = "(member_roles.permissions @> ('{\"see_code\":true}')::jsonb) " \
                        "OR (member_roles.permissions @> ('{\"remove_code\":true}')::jsonb)"

        expect(described_class.elevating.to_sql).to include(expected_sql)
      end

      it 'returns nothing when there are no elevating permissions' do
        admin_member_role.destroy! # the admin role is elevating we need to destroy it before

        create(:member_role)

        expect(described_class.elevating).to be_empty
      end
    end

    describe 'occupies_seat' do
      let_it_be(:member_role_elevating, freeze: false) { create(:member_role, :guest, :admin_vulnerability) }
      let_it_be(:member_role_guest, freeze: false) { create(:member_role, :guest, :read_code) }

      it 'returns member roles for a group' do
        expect(described_class.occupies_seat).to contain_exactly(member_role_elevating)
      end
    end

    describe 'by_namespace' do
      it 'returns member roles for a group' do
        expect(described_class.by_namespace(group)).to match_array([member_role_1, member_role_2])
      end
    end

    describe 'for_instance' do
      let_it_be(:instance_member_role, freeze: false) { create(:member_role, :instance, name: 'Manager') }

      it 'returns member roles created on the instance' do
        expect(described_class.for_instance).to match_array([admin_member_role, instance_member_role])
      end
    end

    describe '#non_admin' do
      it 'returns only non-admin member roles' do
        expect(described_class.non_admin).to match_array([member_role_1, member_role_2, group_2_member_role])
      end
    end

    describe '#admin' do
      it 'returns only admin member roles' do
        expect(described_class.admin).to match_array([admin_member_role])
      end
    end

    describe '.with_members_count' do
      let_it_be(:member_role_1_members, freeze: false) do
        create_list(:group_member, 3, :developer, {
          member_role: member_role_1,
          source: group
        })
      end

      let_it_be(:member_role_2_members, freeze: false) do
        create_list(:group_member, 2, :developer, {
          member_role: member_role_2,
          source: group
        })
      end

      it 'returns the total count of members for each role' do
        expect(described_class.with_members_count.map { |x| [x.id, x.members_count] }).to match_array([
          [member_role_1.id, 3],
          [member_role_2.id, 2],
          [group_2_member_role.id, 0],
          [admin_member_role.id, 0]
        ])
      end
    end

    describe '.with_ldap_admin_role_links' do
      let_it_be(:ldap_link_1, freeze: false) do
        create(:ldap_admin_role_link, member_role: admin_member_role, cn: 'group1', filter: nil)
      end

      let_it_be(:ldap_link_2, freeze: false) do
        create(:ldap_admin_role_link, member_role: admin_member_role, cn: nil, filter: 'uid=john')
      end

      it 'returns ldap admin role links' do
        expect(described_class.with_ldap_admin_role_links.map(&:ldap_admin_role_links)).to match_array([[], [], [],
          [ldap_link_1, ldap_link_2]])
      end
    end
  end

  describe 'before_save' do
    describe '#set_occupies_seat' do
      it 'sets to false when skip_seat_consumption for custom ability is true' do
        member_role = create(:member_role, :guest, :read_code)

        expect(member_role.occupies_seat).to be(false)
      end

      it 'sets to true when skip_seat_consumption for custom ability is false or nil' do
        member_role = create(:member_role, :guest, :admin_terraform_state)

        expect(member_role.occupies_seat).to be(true)
      end

      it 'sets to true when at least one custom ability has skip_seat_consumption set to false or nil' do
        member_role = create(:member_role, :guest, :read_code, :admin_terraform_state)

        expect(member_role.occupies_seat).to be(true)
      end

      it 'sets to true when base role is not guest' do
        member_role = create(:member_role, :reporter, :read_code)

        expect(member_role.occupies_seat).to be(true)
      end
    end
  end

  describe '.levels_sentence' do
    it 'returns the list of access levels with names' do
      expect(described_class.levels_sentence).to eq(
        "10 (Guest), 15 (Planner), 20 (Reporter), 25 (Security Manager), 30 (Developer), " \
        "40 (Maintainer), and 50 (Owner)"
      )
    end
  end

  describe '.should_query_custom_roles?' do
    let_it_be(:namespace, freeze: false) { create(:group) }

    subject { described_class.should_query_custom_roles?(namespace) }

    it { is_expected.to be true }

    context 'when on SaaS', :saas do
      context 'when namespace does not have a custom role' do
        it { is_expected.to be false }

        context 'with caching', :use_clean_rails_redis_caching do
          it 'invalidates the cache when a new custom role is created' do
            expect(described_class.should_query_custom_roles?(namespace)).to be false

            create(:member_role, namespace: namespace)

            expect(described_class.should_query_custom_roles?(namespace)).to be true
          end
        end
      end

      context 'when namespace has a custom role' do
        let_it_be(:custom_role, freeze: false) { create(:member_role, namespace: namespace) }

        it { is_expected.to be true }

        context 'with caching', :use_clean_rails_redis_caching do
          it 'invalidates the cache when a new custom role is destroyed' do
            expect(described_class.should_query_custom_roles?(namespace)).to be true

            custom_role.destroy!

            expect(described_class.should_query_custom_roles?(namespace)).to be false
          end
        end
      end
    end
  end

  describe '#admin_related_role?' do
    let_it_be(:admin_member_role, freeze: false) { build(:member_role, :admin) }
    let_it_be(:standard_member_role) { build(:member_role, :instance) }

    subject(:admin_related_role) { member_role.admin_related_role? }

    context 'when member role has admin permissions enabled' do
      let(:member_role) { admin_member_role }

      it { is_expected.to be true }

      context 'when member role has a base access level' do
        before do
          member_role.base_access_level = 30
        end

        it { is_expected.to be false }
      end
    end

    context 'when member role has standard permissions enabled' do
      let(:member_role) { standard_member_role }

      it { is_expected.to be false }
    end
  end

  describe '#enabled_permissions' do
    let_it_be(:member_role, freeze: false) do
      build(:member_role, read_code: true, read_vulnerability: true, read_dependency: false)
    end

    subject(:enabled_permissions) { member_role.enabled_permissions }

    it 'returns the list of enabled permissions' do
      expect(enabled_permissions.keys).to match_array([:read_code, :read_vulnerability])
    end
  end

  describe '#dependent_security_policies' do
    let_it_be(:namespace, freeze: false) { create(:group) }
    let_it_be(:member_role, freeze: false) { create(:member_role, namespace: namespace) }
    let_it_be(:policy_configuration, freeze: false) do
      create(:security_orchestration_policy_configuration, namespace: namespace, project: nil)
    end

    let_it_be(:security_policy_without_member_role, freeze: false) do
      create(:security_policy)
    end

    let_it_be(:security_policy_for_namespace, freeze: false) do
      create(:security_policy,
        security_orchestration_policy_configuration: policy_configuration,
        content: { actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: [member_role.id] }] })
    end

    let_it_be(:security_policy_for_other_namespace, freeze: false) do
      create(:security_policy,
        security_orchestration_policy_configuration: create(:security_orchestration_policy_configuration),
        content: { actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: [member_role.id] }] })
    end

    subject(:dependent_security_policies) { member_role.dependent_security_policies }

    context 'when not on GitLab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'returns all policies with custom role' do
        is_expected.to contain_exactly(security_policy_for_namespace, security_policy_for_other_namespace)
      end

      context 'when feature is not licensed' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'returns no policies' do
          is_expected.to be_empty
        end
      end
    end

    context 'when on GitLab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        stub_licensed_features(security_orchestration_policies: true)

        allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 2) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end
      end

      it 'returns policies for namespace with custom role' do
        is_expected.to contain_exactly(security_policy_for_namespace)
      end

      context 'when feature is not licensed' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'returns no policies' do
          is_expected.to be_empty
        end
      end
    end
  end
end
