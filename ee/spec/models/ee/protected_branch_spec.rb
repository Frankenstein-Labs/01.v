# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProtectedBranch, feature_category: :source_code_management do
  subject(:protected_branch) { create(:protected_branch) }

  let(:project) { subject.project }
  let(:user) { create(:user) }

  it_behaves_like 'protected ref with ee access levels for', :merge
  it_behaves_like 'protected ref with ee access levels for', :push
  it_behaves_like 'protected ref with access levels for', :unprotect
  it_behaves_like 'protected ref with ee access levels for', :unprotect

  describe 'associations' do
    it { is_expected.to have_many(:unprotect_access_levels).inverse_of(:protected_branch) }
    it { is_expected.to have_many(:required_code_owners_sections).class_name('ProtectedBranch::RequiredCodeOwnersSection') }
    it { is_expected.to have_and_belong_to_many(:approval_project_rules) }

    it do
      is_expected
        .to have_and_belong_to_many(:external_status_checks)
        .class_name('::MergeRequests::ExternalStatusCheck')
    end

    it { is_expected.to have_one(:squash_option) }
    it { is_expected.to have_one(:merge_request_approval_setting) }
  end

  describe '.preload_access_levels' do
    let(:group) { create(:group) }
    let(:member_role) { create(:member_role, namespace: group) }
    let(:protected_branch) { create(:protected_branch, project: nil, group: group, default_access_level: false) }

    before do
      stub_licensed_features(custom_roles: true)
      stub_feature_flags(custom_roles_for_protected_branches: true)
      create(:protected_branch_push_access_level, protected_branch: protected_branch, member_role: member_role)
      create(:protected_branch_merge_access_level, protected_branch: protected_branch, member_role: member_role)
      create(:protected_branch_unprotect_access_level, protected_branch: protected_branch, member_role: member_role)
    end

    it 'preloads member_role on access levels', :aggregate_failures do
      branch = described_class.where(group: group).preload_access_levels.order(:id).first

      expect(branch.push_access_levels.first.association(:member_role)).to be_loaded
      expect(branch.merge_access_levels.first.association(:member_role)).to be_loaded
      expect(branch.unprotect_access_levels.first.association(:member_role)).to be_loaded
    end

    it 'does not trigger additional queries when accessing member_role' do
      branches = described_class.where(group: group).preload_access_levels.to_a

      expect do
        branches.flat_map do |branch|
          branch.push_access_levels.map(&:humanize) +
            branch.merge_access_levels.map(&:humanize) +
            branch.unprotect_access_levels.map(&:humanize)
        end
      end.not_to exceed_query_limit(0)
    end
  end

  shared_examples 'uniqueness validation' do |access_level_class|
    let(:factory_name) { access_level_class.to_s.underscore.sub('/', '_').to_sym }
    let(:association_name) { access_level_class.to_s.underscore.sub('protected_branch/', '').pluralize.to_sym }

    human_association_name = access_level_class.to_s.underscore.humanize.sub('Protected branch/', '')

    context "while checking uniqueness of a role-based #{human_association_name}" do
      it "allows a single #{human_association_name} for a role (per protected branch)" do
        first_protected_branch = create(:protected_branch, default_access_level: false)
        second_protected_branch = create(:protected_branch, default_access_level: false)

        first_protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)
        second_protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)

        expect(first_protected_branch).to be_valid
        expect(second_protected_branch).to be_valid

        first_protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)
        expect(first_protected_branch).to be_invalid
        expect(first_protected_branch.errors.full_messages.first).to match("access level has already been taken")
      end

      it "does not count a user-based #{human_association_name} with an `access_level` set" do
        protected_branch = create(:protected_branch, default_access_level: false)
        protected_branch.project.add_developer(user)

        protected_branch.send(association_name) << build(factory_name, user: user, access_level: Gitlab::Access::MAINTAINER)
        protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)

        expect(protected_branch).to be_valid
      end

      it "does not count a group-based #{human_association_name} with an `access_level` set" do
        group = create(:group)
        protected_branch = create(:protected_branch, default_access_level: false)
        protected_branch.project.project_group_links.create!(group: group)

        protected_branch.send(association_name) << build(factory_name, group: group, access_level: Gitlab::Access::MAINTAINER)
        protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)

        expect(protected_branch).to be_valid
      end
    end

    context "while checking uniqueness of a user-based #{human_association_name}" do
      it "allows a single #{human_association_name} for a user (per protected branch)" do
        first_protected_branch = create(:protected_branch, default_access_level: false)
        second_protected_branch = create(:protected_branch, default_access_level: false)

        first_protected_branch.project.add_developer(user)
        second_protected_branch.project.add_developer(user)

        first_protected_branch.send(association_name) << build(factory_name, user: user)
        second_protected_branch.send(association_name) << build(factory_name, user: user)

        expect(first_protected_branch).to be_valid
        expect(second_protected_branch).to be_valid

        first_protected_branch.send(association_name) << build(factory_name, user: user)
        expect(first_protected_branch).to be_invalid
        expect(first_protected_branch.errors.full_messages.first).to match("user has already been taken")
      end

      it "ignores the `access_level` while validating a user-based #{human_association_name}" do
        protected_branch = create(:protected_branch, default_access_level: false)
        protected_branch.project.add_developer(user)

        protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)
        protected_branch.send(association_name) << build(factory_name, user: user, access_level: Gitlab::Access::MAINTAINER)

        expect(protected_branch).to be_valid
      end
    end

    context "while checking uniqueness of a group-based #{human_association_name}" do
      let(:group) { create(:group) }

      it "allows a single #{human_association_name} for a group (per protected branch)" do
        first_protected_branch = create(:protected_branch, default_access_level: false)
        second_protected_branch = create(:protected_branch, default_access_level: false)

        first_protected_branch.project.project_group_links.create!(group: group)
        second_protected_branch.project.project_group_links.create!(group: group)

        first_protected_branch.send(association_name) << build(factory_name, group: group)
        second_protected_branch.send(association_name) << build(factory_name, group: group)

        expect(first_protected_branch).to be_valid
        expect(second_protected_branch).to be_valid

        first_protected_branch.send(association_name) << build(factory_name, group: group)
        expect(first_protected_branch).to be_invalid
        expect(first_protected_branch.errors.full_messages.first).to match("group has already been taken")
      end

      it "ignores the `access_level` while validating a group-based #{human_association_name}" do
        protected_branch = create(:protected_branch, default_access_level: false)
        protected_branch.project.project_group_links.create!(group: group)

        protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MAINTAINER)
        protected_branch.send(association_name) << build(factory_name, group: group, access_level: Gitlab::Access::MAINTAINER)

        expect(protected_branch).to be_valid
      end
    end
  end

  it_behaves_like 'uniqueness validation', ProtectedBranch::MergeAccessLevel
  it_behaves_like 'uniqueness validation', ProtectedBranch::PushAccessLevel

  describe 'squash options validation' do
    context 'when squash option is being created on an exact branch' do
      let!(:squash_option) { build(:branch_rule_squash_option, project: project, protected_branch: protected_branch) }

      before do
        protected_branch.squash_option = squash_option
      end

      it 'is valid' do
        expect(protected_branch).to be_valid
      end
    end

    context 'when branch name changes to wildcard and a squash option exists' do
      let!(:squash_option) { create(:branch_rule_squash_option, project: project, protected_branch: protected_branch) }

      before do
        protected_branch.name = '*'
      end

      it 'is invalid with error on base' do
        expect(protected_branch).to be_invalid
        expect(protected_branch.errors.full_messages).to include(
          'Squash option cannot be used with wildcard branch rules. Use an exact branch name.'
        )
      end
    end
  end

  describe "#code_owner_approval_required" do
    context "when the attr code_owner_approval_required is true" do
      let(:subject_branch) { create(:protected_branch, code_owner_approval_required: true) }

      it "returns true" do
        expect(subject_branch.project)
          .to receive(:code_owner_approval_required_available?).once.and_return(true)
        expect(subject_branch.code_owner_approval_required).to be_truthy
      end

      it "returns false when the project doesn't require approvals" do
        expect(subject_branch.project)
          .to receive(:code_owner_approval_required_available?).once.and_return(false)
        expect(subject_branch.code_owner_approval_required).to be_falsy
      end
    end

    context "when the attr code_owner_approval_required is false" do
      let(:subject_branch) { create(:protected_branch, code_owner_approval_required: false) }

      it "returns false" do
        expect(subject_branch.code_owner_approval_required).to be_falsy
      end
    end
  end

  describe '#can_unprotect?' do
    let(:admin) { create(:user, :admin) }
    let(:maintainer) do
      create(:user, maintainer_of: project)
    end

    context 'without unprotect_access_levels' do
      it "doesn't add any additional restriction" do
        expect(subject.can_unprotect?(user)).to be true
      end
    end

    context 'with access level set to MAINTAINER' do
      before do
        subject.unprotect_access_levels.create!(access_level: Gitlab::Access::MAINTAINER)
      end

      it 'prevents access to users' do
        expect(subject.can_unprotect?(user)).to be(false)
      end

      it 'grants access to maintainers' do
        expect(subject.can_unprotect?(maintainer)).to be(true)
      end

      it 'prevents access to admins' do
        expect(subject.can_unprotect?(admin)).to be(false)
      end
    end

    context 'with access level set to ADMIN' do
      before do
        subject.unprotect_access_levels.create!(access_level: Gitlab::Access::ADMIN)
      end

      it 'prevents access to maintainers' do
        expect(subject.can_unprotect?(maintainer)).to be(false)
      end

      it 'grants access to admins' do
        expect(subject.can_unprotect?(admin)).to be(true)
      end
    end

    context 'multiple access levels' do
      before do
        project.add_developer(user)
        subject.unprotect_access_levels.create!(user: maintainer)
        subject.unprotect_access_levels.create!(user: user)
      end

      it 'grants access if any grant access' do
        expect(subject.can_unprotect?(user)).to be true
      end
    end
  end

  describe '.branch_requires_code_owner_approval?' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let(:branch_name) { "BRANCH_NAME" }

    before do
      allow(project).to receive(:code_owner_approval_required_available?).and_return(true)
    end

    subject { described_class.branch_requires_code_owner_approval?(project, branch_name) }

    context 'when there are no match branches' do
      it { is_expected.to be(false) }
    end

    context 'when `code_owner_approval_required_available?` of project is false' do
      before do
        allow(project).to receive(:code_owner_approval_required_available?).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'when there are matched branches' do
      using RSpec::Parameterized::TableSyntax

      where(:object, :code_owner_approval_required, :result) do
        ref(:project)         | false        | false
        ref(:project)         | true         | true
        ref(:group)           | false        | false
        ref(:group)           | true         | true
      end

      with_them do
        before do
          params = object.is_a?(Project) ? { project: object } : { project: nil, group: object }

          create(:protected_branch, name: branch_name, code_owner_approval_required: code_owner_approval_required, **params)
        end

        it { is_expected.to eq(result) }
      end
    end

    context 'when there are matched branches - quarantined examples',
      quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/470328' do
      using RSpec::Parameterized::TableSyntax

      where(:object, :code_owner_approval_required, :result) do
        ref(:group) | true | true
      end

      with_them do
        before do
          params = object.is_a?(Project) ? { project: object } : { project: nil, group: object }

          create(:protected_branch, name: branch_name, code_owner_approval_required: code_owner_approval_required, **params)
        end

        it { is_expected.to eq(result) }
      end
    end
  end

  describe '#inherited?' do
    context 'when the `namespace_id` is nil' do
      before do
        subject.assign_attributes(namespace_id: nil)
      end

      it { is_expected.not_to be_inherited }
    end

    context 'when the `namespace_id` is present' do
      before do
        subject.assign_attributes(namespace_id: 123)
      end

      it { is_expected.to be_inherited }
    end
  end

  describe '#supports_unprotection_restrictions?' do
    subject(:supports_unprotection_restrictions) { protected_branch.supports_unprotection_restrictions? }

    context 'when the `namespace_id` is nil' do
      before do
        protected_branch.assign_attributes(namespace_id: nil)
      end

      context 'when feature is not licensed' do
        before do
          stub_licensed_features(unprotection_restrictions: false)
        end

        it { is_expected.to be_falsey }

        it 'does not load group without a reason' do
          expect { subject }.not_to exceed_query_limit(0)
        end
      end

      context 'when feature is licensed' do
        before do
          stub_licensed_features(unprotection_restrictions: true)
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when the `namespace_id` is present' do
      before do
        protected_branch.assign_attributes(namespace_id: 123)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#allow_force_push' do
    context 'when is not protected from push by security policy' do
      context 'when the `allow_force_push` is true' do
        before do
          subject.assign_attributes(allow_force_push: true)
        end

        it { is_expected.to be_allow_force_push }
      end

      context 'when the `allow_force_push` is false' do
        before do
          subject.assign_attributes(allow_force_push: false)
        end

        it { is_expected.not_to be_allow_force_push }
      end
    end

    context 'when is protected from push by security policy and the `allow_force_push` is true' do
      before do
        subject.assign_attributes(allow_force_push: true)
        allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ProtectedBranchesPushService) do |service|
          allow(service).to receive(:execute).and_return([protected_branch.name])
        end
      end

      context 'when feature is not licensed' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it { is_expected.to be_allow_force_push }
      end

      context 'when feature is licensed' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        context 'when protected branch is created on group level' do
          let_it_be_with_reload(:group) { create(:group) }

          before do
            subject.assign_attributes(group: group)
          end

          it { is_expected.to be_allow_force_push }
        end

        context 'when protected branch is created on project level' do
          it { is_expected.not_to be_allow_force_push }
        end
      end
    end
  end

  describe '#modification_blocked_by_policy?' do
    subject(:result) { protected_branch.modification_blocked_by_policy? }

    before do
      project.repository.add_branch(project.creator, branch_name, 'HEAD')
    end

    context 'with project-level protected branch' do
      let(:project) { create(:project, :small_repo) }
      let(:protected_branch) { create(:protected_branch, project: project) }
      let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }

      context 'without blocking approval policy' do
        let(:approval_policies) { [] }

        it { is_expected.to be(false) }
      end

      include_context 'with approval policy blocking protected branches' do
        let(:branch_name) { protected_branch.name }

        it { is_expected.to be(true) }

        context 'without feature available' do
          before do
            stub_licensed_features(security_orchestration_policies: false)
          end

          it { is_expected.to be(false) }
        end

        context 'with mismatching name' do
          let(:branch_name) { protected_branch.name.reverse }

          it { is_expected.to be(false) }
        end

        context 'when protected branch is not backed by git ref' do
          before do
            project.repository.delete_branch(branch_name)
          end

          after do
            project.repository.add_branch(project.creator, branch_name, 'HEAD')
          end

          it { is_expected.to be(true) }
        end
      end

      include_context 'with persisted approval policies'
    end

    context 'with group-level protected branch' do
      let(:group) { create(:group) }
      let(:project) { create(:project, :small_repo, group: group) }
      let(:protected_branch) { create(:protected_branch, :group_level, group: group) }
      let(:policy_configuration) { create(:security_orchestration_policy_configuration, :namespace, namespace: group) }

      context 'without blocking approval policy' do
        let(:approval_policies) { [] }

        it { is_expected.to be(false) }
      end

      include_context 'with approval policy blocking group-level protected branches' do
        let(:branch_name) { protected_branch.name }

        it { is_expected.to be(true) }

        context 'without feature available' do
          before do
            stub_licensed_features(security_orchestration_policies: false)
          end

          it { is_expected.to be(false) }
        end
      end

      include_context 'with persisted approval policies'

      context 'when excepted' do
        let(:approval_policy) do
          build(:approval_policy,
            branch_type: 'protected',
            approval_settings: { block_group_branch_modification: { enabled: true, exceptions: [{ id: group.id }] } })
        end

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#protected_from_push_by_security_policy?' do
    subject(:result) { protected_branch.protected_from_push_by_security_policy? }

    before do
      stub_licensed_features(security_orchestration_policies: true)
      project.repository.add_branch(project.creator, branch_name, 'HEAD')
    end

    context 'with project-level protected branch' do
      let_it_be_with_reload(:project) { create(:project, :small_repo) }
      let_it_be_with_refind(:protected_branch) { create(:protected_branch, project: project) }
      let_it_be_with_refind(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
      let(:branch_name) { protected_branch.name }

      context 'without blocking approval policy' do
        it { is_expected.to be(false) }
      end

      context 'with blocking approval policy' do
        include_context 'with approval security policy preventing force pushing'

        it { is_expected.to be(true) }

        context 'without feature available' do
          before do
            stub_licensed_features(security_orchestration_policies: false)
          end

          it { is_expected.to be(false) }
        end

        context 'with mismatching name' do
          before do
            approval_policy_rule_preventing_force_pushing.update!(
              content: approval_policy_rule_preventing_force_pushing.content.merge('branches' => ['other_branch'])
            )
          end

          it { is_expected.to be(false) }
        end
      end

      include_context 'with persisted approval policies'
    end

    context 'with group-level protected branch' do
      let(:group) { create(:group) }
      let(:project) { create(:project, :small_repo, group: group) }
      let(:protected_branch) { create(:protected_branch, :group_level, group: group) }
      let(:branch_name) { protected_branch.name }

      it { is_expected.to be(false) }
    end
  end

  describe '#warn_modification_blocked_by_policy?' do
    subject(:result) { protected_branch.warn_modification_blocked_by_policy? }

    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, :small_repo, group: group) }
    let(:branch_name) { protected_branch.name }

    context 'with project-level protected branch' do
      let_it_be_with_refind(:protected_branch) { create(:protected_branch, project: project) }

      before do
        project.repository.add_branch(project.creator, branch_name, 'HEAD')
      end

      context 'without feature available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it { is_expected.to be(false) }
      end

      context 'with feature available' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        context 'when check service returns empty without ignore_warn_mode but returns branch with ignore_warn_mode' do
          before do
            allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ProtectedBranchesDeletionCheckService) do |service|
              allow(service).to receive(:execute).and_return([])
            end
            allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ProtectedBranchesDeletionCheckService, project: project, current_user: nil, ignore_warn_mode: true) do |service|
              allow(service).to receive(:execute).and_return([protected_branch])
            end
          end

          it { is_expected.to be(true) }
        end

        context 'when check service returns empty regardless of ignore_warn_mode' do
          before do
            allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ProtectedBranchesDeletionCheckService) do |service|
              allow(service).to receive(:execute).and_return([])
            end
          end

          it { is_expected.to be(false) }
        end
      end
    end

    context 'with group-level protected branch' do
      let_it_be_with_refind(:protected_branch) { create(:protected_branch, :group_level, group: group) }

      before do
        project.repository.add_branch(project.creator, branch_name, 'HEAD')
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'without feature available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it { is_expected.to be(false) }
      end

      context 'with feature available' do
        context 'when check returns false without ignore_warn_mode but returns true with ignore_warn_mode' do
          before do
            allow_next_instance_of(::Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService) do |service|
              allow(service).to receive(:execute).and_return(false)
            end
            allow_next_instance_of(::Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService, group: group, current_user: nil, ignore_warn_mode: true) do |service|
              allow(service).to receive(:execute).and_return(true)
            end
          end

          it { is_expected.to be(true) }
        end

        context 'when check service returns false regardless of ignore_warn_mode' do
          before do
            allow_next_instance_of(::Security::SecurityOrchestrationPolicies::GroupProtectedBranchesDeletionCheckService) do |service|
              allow(service).to receive(:execute).and_return(false)
            end
          end

          it { is_expected.to be(false) }
        end
      end
    end
  end

  describe '#warn_protected_from_push_by_security_policy?' do
    subject(:result) { protected_branch.warn_protected_from_push_by_security_policy? }

    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, :small_repo, group: group) }
    let_it_be_with_refind(:protected_branch) { create(:protected_branch, project: project) }
    let(:branch_name) { protected_branch.name }

    before do
      project.repository.add_branch(project.creator, branch_name, 'HEAD')
    end

    context 'without feature available' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
      end

      it { is_expected.to be(false) }
    end

    context 'with feature available' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when push service returns empty without ignore_warn_mode but returns branch with ignore_warn_mode' do
        before do
          allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ProtectedBranchesPushService) do |service|
            allow(service).to receive(:execute).and_return([])
          end
          allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ProtectedBranchesPushService, project: project, ignore_warn_mode: true) do |service|
            allow(service).to receive(:execute).and_return([branch_name])
          end
        end

        it { is_expected.to be(true) }

        context 'with mismatching name' do
          before do
            protected_branch.update!(name: 'other_branch')
          end

          it { is_expected.to be(false) }
        end
      end

      context 'when push service returns empty regardless of ignore_warn_mode' do
        before do
          allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ProtectedBranchesPushService) do |service|
            allow(service).to receive(:execute).and_return([])
          end
        end

        it { is_expected.to be(false) }
      end
    end

    context 'with group-level protected branch' do
      let_it_be(:protected_branch) { create(:protected_branch, :group_level, group: group) }

      it 'returns false (group-level branches are not project-level)' do
        expect(result).to be(false)
      end
    end
  end

  describe '.protected_ref_accessible_to?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, namespace: group) }
    let_it_be(:policy_project) { create(:project, namespace: group) }
    let_it_be(:current_user) { create(:user) }

    subject { described_class.protected_ref_accessible_to?(anything, current_user, project: policy_project, action: :push) }

    context 'when project is a security policy project and empty' do
      before_all do
        policy_project.add_developer(current_user)
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)

        allow(policy_project).to receive(:empty_repo?).and_return(true)
        allow(policy_project.namespace).to receive(:default_branch_protection_settings)
          .and_return(Gitlab::Access::BranchProtection.protected_fully)
      end

      context 'when target is a project' do
        before_all do
          create(:security_orchestration_policy_configuration, security_policy_management_project: policy_project, project: project)
        end

        where(:role, :expected) do
          :owner      | true
          :maintainer | false
          :developer  | false
        end

        with_them do
          before do
            project.public_send(:"add_#{role}", current_user)
          end

          it { is_expected.to be(expected) }
        end

        context 'when the policy project is already configured for another project' do
          let_it_be(:other_project) { create(:project, namespace: group) }

          before_all do
            create(:security_orchestration_policy_configuration, security_policy_management_project: policy_project, project: other_project)
          end

          it 'returns false when user don\'t have permissions to either target projects' do
            expect(subject).to be(false)
          end

          it 'returns true when user have access to one of the target project' do
            project.add_developer(current_user)
            other_project.add_owner(current_user)

            expect(subject).to be(true)
          end
        end
      end

      context 'when target is a group' do
        before_all do
          create(:security_orchestration_policy_configuration, :namespace, security_policy_management_project: policy_project, namespace: group)
        end

        where(:role, :expected) do
          :owner      | true
          :maintainer | true
          :developer  | false
        end

        with_them do
          before do
            group.public_send(:"add_#{role}", current_user)
          end

          it { is_expected.to be(expected) }
        end
      end
    end
  end
end
