# frozen_string_literal: true

RSpec.shared_examples 'ee protected branch access' do
  include_context 'for protected ref access'

  let_it_be(:member_role) { create(:member_role, namespace: project.group) }
  let_it_be(:test_member_role) { create(:member_role, namespace: project.group) }

  let(:custom_roles_enabled) { true }

  before do
    stub_licensed_features(custom_roles: custom_roles_enabled)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:member_role).optional }
  end

  describe 'validations' do
    context 'when member_role_id is present' do
      context 'when member_role exists' do
        subject(:access_level) do
          build(described_factory, protected_ref_name => protected_ref, member_role: member_role)
        end

        it { is_expected.to be_valid }
      end

      context 'when member_role does not exist' do
        subject(:access_level) do
          build(described_factory, protected_ref_name => protected_ref, member_role_id: 0)
        end

        it 'is not valid', :aggregate_failures do
          is_expected.to be_invalid
          expect(access_level.errors.full_messages).to include("Member role can't be blank")
        end
      end

      context 'when a member_role already added for this protected ref' do
        before do
          create(described_factory, protected_ref_name => protected_ref, member_role: member_role)
        end

        subject(:access_level) do
          build(described_factory, protected_ref_name => protected_ref, member_role: member_role)
        end

        it 'is not valid', :aggregate_failures do
          is_expected.to be_invalid
          expect(access_level.errors.full_messages).to contain_exactly('Member role has already been taken')
        end
      end
    end

    describe 'namespace validation' do
      context 'when member_role belongs to the same root namespace' do
        subject(:access_level) do
          build(described_factory, protected_ref_name => protected_ref, member_role: member_role)
        end

        it { is_expected.to be_valid }

        context 'when custom roles is unlicensed' do
          let(:custom_roles_enabled) { false }

          it 'is not valid', :aggregate_failures do
            is_expected.to be_invalid
            expect(access_level.errors.full_messages)
              .to include('Member role is not licensed for the root namespace')
          end
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(custom_roles_for_protected_branches: false)
          end

          it 'is not valid', :aggregate_failures do
            is_expected.to be_invalid
            expect(access_level.errors.full_messages)
              .to include('Member role is not licensed for the root namespace')
          end
        end
      end

      context 'when member_role belongs to a different namespace' do
        let_it_be(:other_namespace) { create(:group) }
        let_it_be(:other_member_role) { create(:member_role, namespace: other_namespace) }

        subject(:access_level) do
          build(described_factory, protected_ref_name => protected_ref, member_role: other_member_role)
        end

        it 'is not valid', :aggregate_failures do
          is_expected.to be_invalid
          expect(access_level.errors.full_messages)
            .to include('Member role must belong to the same root namespace as the project or group')
        end
      end

      context 'when importing' do
        let_it_be(:other_namespace) { create(:group) }
        let_it_be(:other_member_role) { create(:member_role, namespace: other_namespace) }

        subject(:access_level) do
          build(described_factory, protected_ref_name => protected_ref,
            member_role: other_member_role, importing: true)
        end

        it { is_expected.to be_valid }
      end
    end
  end

  describe 'scopes' do
    describe '.for_role' do
      let!(:developer_access) { create(described_factory, :developer_access) }
      let!(:maintainer_access) { create(described_factory, :maintainer_access) }
      let!(:member_role_access) do
        create(described_factory, protected_ref_name => protected_ref, member_role: test_member_role)
      end

      it 'excludes member-role rows' do
        expect(described_class.for_role).not_to include(member_role_access)
      end

      it 'includes role-based access levels' do
        expect(described_class.for_role).to include(developer_access, maintainer_access)
      end
    end
  end

  describe '#type' do
    subject { access_level.type }

    context 'when member_role is present and member_role_id is nil' do
      let(:access_level) do
        build(described_factory).tap { |al| al.member_role = build(:member_role) }
      end

      it { is_expected.to eq(:member_role) }
    end

    context 'when member_role_id is present and member_role is nil' do
      let(:access_level) { build(described_factory, member_role_id: 0) }

      it { is_expected.to eq(:member_role) }
    end

    context 'when member_role_id is nil' do
      let(:access_level) { build(described_factory) }

      it { is_expected.to eq(:role) }
    end
  end

  describe '#humanize' do
    subject { access_level.humanize }

    context 'when member_role is present' do
      let(:access_level) do
        build(described_factory, protected_ref_name => protected_ref, member_role: member_role)
      end

      it { is_expected.to eq(member_role.name) }
    end

    context 'when member_role_id is present and member_role is nil' do
      let(:access_level) { build(described_factory, member_role_id: 0) }

      it { is_expected.to eq('Custom Role') }
    end
  end

  describe '#check_access with member_role' do
    let_it_be(:group) { project.group }
    let_it_be(:current_user) { create(:user) }

    subject(:check_access) do
      access_level.check_access(current_user, current_project)
    end

    context 'with project-level protected branch' do
      # Customers can create member_role access levels while they hold a license that
      # includes custom roles. If their license later expires, these records still exist
      # in the database. We skip validation here to simulate that scenario so we can test
      # that check_access denies access when the license is no longer active.
      let(:access_level) do
        build(described_factory, protected_ref_name => protected_ref, member_role: member_role)
          .tap { |record| record.save!(validate: false) }
      end

      context 'when user has the exact member_role assigned via project membership' do
        before do
          create(
            :project_member, :developer, project: project, user: current_user, member_role: member_role
          )
        end

        context 'when current_project is passed' do
          let(:current_project) { project }

          it { is_expected.to be(true) }

          context 'when custom roles is unlicensed' do
            let(:custom_roles_enabled) { false }

            it { is_expected.to be(false) }
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(custom_roles_for_protected_branches: false)
            end

            it { is_expected.to be(false) }
          end
        end

        context 'when current_project is not passed' do
          let(:current_project) { nil }

          it { is_expected.to be(true) }

          context 'when custom roles is unlicensed' do
            let(:custom_roles_enabled) { false }

            it { is_expected.to be(false) }
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(custom_roles_for_protected_branches: false)
            end

            it { is_expected.to be(false) }
          end
        end
      end

      context 'when user has a different custom role with the same base_access_level' do
        let_it_be(:other_role) { create(:member_role, namespace: group) }

        before do
          create(:project_member, :developer, project: project, user: current_user, member_role: other_role)
        end

        context 'when current_project is passed' do
          let(:current_project) { project }

          it { is_expected.to be(false) }
        end

        context 'when current_project is not passed' do
          let(:current_project) { nil }

          it { is_expected.to be(false) }
        end
      end

      context 'when user has no custom role (plain member)' do
        before do
          create(:project_member, :developer, project: project, user: current_user)
        end

        context 'when current_project is passed' do
          let(:current_project) { project }

          it { is_expected.to be(false) }
        end

        context 'when current_project is not passed' do
          let(:current_project) { nil }

          it { is_expected.to be(false) }
        end
      end

      context 'when user is not a member of the project' do
        context 'when current_project is passed' do
          let(:current_project) { project }

          it { is_expected.to be(false) }
        end

        context 'when current_project is not passed' do
          let(:current_project) { nil }

          it { is_expected.to be(false) }
        end
      end

      context 'when user has the member_role assigned via group hierarchy' do
        before do
          create(
            :group_member, :developer, group: group, user: current_user, member_role: member_role
          )
        end

        context 'when current_project is passed' do
          let(:current_project) { project }

          it { is_expected.to be(true) }

          context 'when custom roles is unlicensed' do
            let(:custom_roles_enabled) { false }

            it { is_expected.to be(false) }
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(custom_roles_for_protected_branches: false)
            end

            it { is_expected.to be(false) }
          end
        end

        context 'when current_project is not passed' do
          let(:current_project) { nil }

          it { is_expected.to be(true) }

          context 'when custom roles is unlicensed' do
            let(:custom_roles_enabled) { false }

            it { is_expected.to be(false) }
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(custom_roles_for_protected_branches: false)
            end

            it { is_expected.to be(false) }
          end
        end
      end
    end

    context 'with group-level protected branch' do
      let_it_be(:group_for_branch, freeze: false) { create(:group) }
      let_it_be(:group_protected_ref, freeze: false) do
        create(:protected_branch, :group_level, group: group_for_branch, default_access_level: false)
      end

      let_it_be(:group_member_role, freeze: false) { create(:member_role, namespace: group_for_branch) }
      let_it_be(:project_in_group, freeze: false) { create(:project, group: group_for_branch) }

      # Customers can create member_role access levels while they hold a license that
      # includes custom roles. If their license later expires, these records still exist
      # in the database. We skip validation here to simulate that scenario so we can test
      # that check_access denies access when the license is no longer active.
      let(:access_level) do
        build(described_factory, protected_ref_name => group_protected_ref, member_role: group_member_role)
          .tap { |record| record.save!(validate: false) }
      end

      context 'when user has the role via group membership' do
        before do
          create(
            :group_member, :developer,
            group: group_for_branch,
            user: current_user,
            member_role: group_member_role
          )
        end

        context 'when current_project is not passed' do
          let(:current_project) { nil }

          it { is_expected.to be(true) }

          context 'when custom roles is unlicensed' do
            let(:custom_roles_enabled) { false }

            it { is_expected.to be(false) }
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(custom_roles_for_protected_branches: false)
            end

            it { is_expected.to be(false) }
          end
        end

        context 'when current_project is passed' do
          let(:current_project) { project_in_group }

          it { is_expected.to be(true) }

          context 'when custom roles is unlicensed' do
            let(:custom_roles_enabled) { false }

            it { is_expected.to be(false) }
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(custom_roles_for_protected_branches: false)
            end

            it { is_expected.to be(false) }
          end
        end
      end

      context 'when user has the role only at project level (not group)' do
        before do
          create(
            :project_member, :developer,
            project: project_in_group,
            user: current_user,
            member_role: group_member_role
          )
        end

        context 'when current_project is not passed' do
          let(:current_project) { nil }

          it { is_expected.to be(false) }
        end

        context 'when current_project is passed' do
          let(:current_project) { project_in_group }

          it { is_expected.to be(true) }

          context 'when custom roles is unlicensed' do
            let(:custom_roles_enabled) { false }

            it { is_expected.to be(false) }
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(custom_roles_for_protected_branches: false)
            end

            it { is_expected.to be(false) }
          end
        end
      end

      context 'when user is not a member' do
        context 'when current_project is not passed' do
          let(:current_project) { nil }

          it { is_expected.to be(false) }
        end

        context 'when current_project is passed' do
          let(:current_project) { project_in_group }

          it { is_expected.to be(false) }
        end
      end

      context 'when user has a different custom role with the same base_access_level' do
        let_it_be(:other_group_role) { create(:member_role, namespace: group_for_branch) }

        before do
          create(
            :group_member, :developer,
            group: group_for_branch,
            user: current_user,
            member_role: other_group_role
          )
        end

        context 'when current_project is not passed' do
          let(:current_project) { nil }

          it { is_expected.to be(false) }
        end

        context 'when current_project is passed' do
          let(:current_project) { project_in_group }

          it { is_expected.to be(false) }
        end
      end

      context 'when user has no custom role (plain group member)' do
        before do
          create(:group_member, :developer, group: group_for_branch, user: current_user)
        end

        context 'when current_project is not passed' do
          let(:current_project) { nil }

          it { is_expected.to be(false) }
        end

        context 'when current_project is passed' do
          let(:current_project) { project_in_group }

          it { is_expected.to be(false) }
        end
      end
    end
  end
end
