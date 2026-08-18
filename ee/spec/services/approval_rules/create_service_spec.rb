# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::CreateService, feature_category: :source_code_management do
  let_it_be(:project, freeze: false) { create(:project) }
  let_it_be(:group, freeze: false) { create(:group, projects: [project]) }
  let_it_be(:user) { project.creator }

  shared_examples 'creatable' do
    let_it_be(:new_approvers) { create_list(:user, 2) }
    let_it_be(:new_groups) { create_list(:group, 2, :private) }

    context 'for basic creation action' do
      let(:result) do
        described_class.new(target, user, {
          name: 'security',
          approvals_required: 1,
          user_ids: new_approvers.map(&:id),
          group_ids: new_groups.map(&:id)
        }).execute
      end

      it 'creates approval, excluding non-eligible users and groups' do
        expect(result[:status]).to eq(:success)
        rule = result[:rule]

        expect(rule.name).to eq('security')
        expect(rule.approvals_required).to eq(1)
        expect(rule.users).to be_empty
        expect(rule.groups).to be_empty
      end

      it 'tracks creation event via a usage counter' do
        expect(Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter)
          .to receive(:track_approval_rule_added_action).once.with(user: user)

        result
      end
    end

    context 'when some users and groups are eligible' do
      before_all do
        project.add_reporter new_approvers.first
        group.add_member(new_approvers.first, GroupMember::DEVELOPER)
        new_groups.first.add_guest(user)
      end

      it 'creates and includes eligible users and groups' do
        result = described_class.new(target, user, {
          name: 'security',
          approvals_required: 1,
          user_ids: new_approvers.map(&:id),
          group_ids: new_groups.map(&:id)
        }).execute

        expect(result[:status]).to eq(:success)

        rule = result[:rule]

        expect(rule.name).to eq('security')
        expect(rule.approvals_required).to eq(1)
        expect(rule.users).to contain_exactly(new_approvers.first)
        expect(rule.groups).to contain_exactly(new_groups.first)
      end
    end

    context 'when group is a subgroup with indirect permissions' do
      let_it_be(:subgroup) { create(:group, :private, parent: new_groups.first) }

      before_all do
        new_groups.first.add_guest(user)
      end

      it 'creates and includes eligible groups and subgroups' do
        result = described_class.new(target, user, {
          name: 'security',
          approvals_required: 1,
          group_ids: new_groups.map(&:id) + [subgroup.id]
        }).execute

        expect(result[:status]).to eq(:success)

        rule = result[:rule]

        expect(rule.name).to eq('security')
        expect(rule.approvals_required).to eq(1)
        expect(rule.groups).to contain_exactly(new_groups.first, subgroup)
      end
    end

    context 'when validation fails' do
      it 'returns error message' do
        result = described_class.new(target, user, {
          name: nil,
          approvals_required: 1
        }).execute

        expect(result[:status]).to eq(:error)
      end

      it_behaves_like 'does not record an onboarding progress action' do
        subject do
          described_class.new(target, user, {
            name: nil,
            approvals_required: 1
          }).execute
        end
      end
    end

    context 'when user does not have right to admin project or group' do
      let_it_be(:user1) { create(:user) }

      it 'returns error message' do
        result = described_class.new(target, user1, {
          approvals_required: 1
        }).execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to include('Prohibited')
      end

      it 'checks the create_approval_rule ability against the target' do
        allow(Ability).to receive(:allowed?).and_call_original
        expect(Ability).to receive(:allowed?)
          .with(user1, :create_approval_rule, target)
          .and_call_original

        described_class.new(target, user1, { approvals_required: 1 }).execute
      end

      context 'when skip_authorization is true' do
        it 'does not return error message' do
          result = described_class.new(target, user, {
            approvals_required: 1,
            skip_authorization: true
          }).execute

          expect(result[:status]).to eq(:success)
        end
      end
    end

    # Possible when policy configuration last commit user email is not present in GitLab.
    # See: https://gitlab.com/gitlab-org/gitlab/-/issues/402173#note_1348667122
    context 'when user is not present in GitLab' do
      let(:non_existing_user) { nil }
      let(:name) { 'security' }

      let(:result) do
        described_class.new(target, non_existing_user, {
          name: name,
          skip_authorization: true,
          approvals_required: 1,
          user_ids: new_approvers.map(&:id).append(user.id),
          group_ids: new_groups.map(&:id)
        }).execute
      end

      it 'creates approval, excluding non-eligible users and groups', :aggregate_failures do
        expect(result[:status]).to eq(:success)

        rule = result[:rule]

        expect(rule.name).to eq('security')
        expect(rule.approvals_required).to eq(1)
        expect(rule.users).to match_array([user])
        expect(rule.groups).to be_empty
      end

      it 'creates approval without audit' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(
          hash_including(name: 'approval_rule_created')
        )

        expect(result[:status]).to eq(:success)
      end

      context 'when validation fails' do
        let(:name) { nil }

        it 'returns error message' do
          expect(result[:status]).to eq(:error)
          expect(result[:message][:name].first).to eq("can't be blank")
        end
      end
    end

    context 'when approval rule with empty users and groups is being created' do
      subject { described_class.new(target, user, { user_ids: [], group_ids: [] }) }

      it 'sets default attributes for any-approver rule' do
        rule = subject.execute[:rule]

        expect(rule[:rule_type]).to eq('any_approver')
        expect(rule[:name]).to eq('All Members')
      end
    end

    context 'when any-approver rule exists' do
      before do
        target.approval_rules.create!(rule_type: :any_approver, name: 'All members')
      end

      context 'when multiple approval rules are not enabled' do
        subject { described_class.new(target, user, { user_ids: [1], group_ids: [] }) }

        it 'removes the rule if a regular one is created' do
          expect { subject.execute }.to change { target.approval_rules.any_approver.count }.from(1).to(0)
        end
      end

      context 'when multiple approval rules are enabled' do
        subject { described_class.new(target, user, { user_ids: [1], group_ids: [] }) }

        before do
          stub_licensed_features(multiple_approval_rules: true)
        end

        it 'does not remove any approval rule' do
          expect { subject.execute }.not_to change { target.approval_rules.any_approver.count }
        end
      end
    end
  end

  shared_examples 'onboarding progress action' do
    it_behaves_like 'records an onboarding progress action', :required_mr_approvals_enabled do
      let(:namespace) { project.namespace }

      subject do
        described_class.new(target, user, {
          name: 'security',
          approvals_required: 1
        }).execute
      end
    end
  end

  context 'when target is group' do
    let(:target) { group }
    let(:name) { 'group approval rule' }
    let(:params) do
      {
        name: name,
        approvals_required: 1
      }
    end

    subject do
      described_class.new(
        target,
        user,
        params
      ).execute
    end

    context 'when user is a maintainer' do
      before do
        target.add_maintainer(user)
      end

      it 'returns a reason :access_denied' do
        expect(subject.reason).to eq(:access_denied)
      end
    end

    context 'when user is an owner' do
      before do
        target.add_owner(user)
      end

      it_behaves_like "creatable"

      context 'when approval rule lock is enabled' do
        before do
          stub_licensed_features(admin_merge_request_approvers_rules: true, merge_request_approvers: true)
          stub_application_setting(disable_overriding_approvers_per_merge_request: true)
        end

        it 'prevents a non-admin owner from creating the rule' do
          expect(subject[:status]).to eq(:error)
          expect(subject[:message]).to include('Prohibited')
          expect(subject.reason).to eq(:access_denied)
        end

        context 'when user is an admin', :enable_admin_mode do
          let_it_be(:admin) { create(:admin) }

          subject do
            described_class.new(target, admin, params).execute
          end

          it 'allows the admin to create the rule' do
            expect(subject[:status]).to eq(:success)
          end
        end
      end

      context 'when approval_group_rules is disabled for group' do
        before do
          stub_feature_flags(approval_group_rules: false)
        end

        it 'returns an error' do
          expect(subject[:status]).to eq(:error)
          expect(subject[:message]).to eq('The feature approval_group_rules is not enabled.')
        end
      end

      context 'and multiple approval rules are enabled' do
        before do
          stub_licensed_features(multiple_approval_rules: true)
        end

        context 'when protected_branch_ids param is present' do
          let(:protected_branch) { create(:protected_branch, project: nil, group: group) }
          let(:protected_branch_ids) { [protected_branch.id] }
          let(:params) do
            {
              name: name,
              approvals_required: 1,
              skip_authorization: true
            }
          end

          it 'does not associate the group approval rule to the protected branches' do
            expect(subject[:status]).to eq(:success)
            expect(subject[:rule].protected_branches).to eq([])
          end
        end

        context 'when applies_to_all_protected_branches is set to false' do
          let(:protected_branch) { create(:protected_branch, project: nil, group: group) }
          let(:params) do
            {
              name: name,
              approvals_required: 1,
              skip_authorization: true,
              applies_to_all_protected_branches: false
            }
          end

          it 'throws a validation error' do
            expect(subject[:status]).to eq(:error)
          end
        end
      end
    end
  end

  context 'when target is project' do
    let(:target) { project }

    it_behaves_like "creatable"

    it_behaves_like 'onboarding progress action'

    context 'when protected_branch_ids param is present' do
      let(:protected_branch) { create(:protected_branch, project: target) }
      let(:skip_authorization) { false }
      let(:protected_branch_ids) { [protected_branch.id] }

      subject do
        described_class.new(
          target,
          user,
          name: 'developers',
          approvals_required: 1,
          skip_authorization: skip_authorization,
          protected_branch_ids: protected_branch_ids
        ).execute
      end

      context 'and multiple approval rules is enabled' do
        before do
          stub_licensed_features(multiple_approval_rules: true)
        end

        it 'associates the approval rule to the protected branch' do
          expect(subject[:status]).to eq(:success)
          expect(subject[:rule].protected_branches).to eq([protected_branch])
        end

        context 'when user cannot administer project' do
          before do
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(user, :admin_project, target).and_return(false)
          end

          it 'does not associate the approval rule to the protected branch' do
            expect(subject[:status]).to eq(:success)
            expect(subject[:rule].protected_branches).to be_empty
          end
        end

        context 'when skip_authorization param is true' do
          let(:skip_authorization) { true }

          before do
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(user, :admin_project, target).and_return(false)
          end

          it 'associates the approval rule to the protected branch' do
            expect(subject[:status]).to eq(:success)
            expect(subject[:rule].protected_branches).to match_array([protected_branch])
          end
        end

        context 'when protected branch is for another project' do
          let(:another_project) { create(:project) }
          let(:protected_branch) { create(:protected_branch, project: another_project) }

          it 'does not associate the approval rule to the protected branch' do
            expect(subject[:status]).to eq(:success)
            expect(subject[:rule].protected_branches).to be_empty
          end
        end

        it 'associates the approval rule to the protected branch' do
          expect(subject[:status]).to eq(:success)
          expect(subject[:rule].protected_branches).to match_array([protected_branch])
        end

        context 'when the root_namespace of project is a group' do
          let_it_be(:user, freeze: false) { create(:user) }
          let_it_be(:group, freeze: false) { create(:group) }
          let_it_be(:project, freeze: false) { create(:project, group: group, maintainers: user) }
          let_it_be(:group_protected_branch) { create(:protected_branch, project: nil, group: group) }

          let(:protected_branch_ids) { [protected_branch.id, group_protected_branch.id] }

          it 'associates the approval rule to the all protected branches' do
            expect(subject[:status]).to eq(:success)
            expect(subject[:rule].protected_branches).to match_array([protected_branch, group_protected_branch])
          end
        end
      end

      context 'and multiple approval rules is disabled' do
        it 'does not associate the approval rule to the protected branch' do
          expect(subject[:status]).to eq(:success)
          expect(subject[:rule].protected_branches).to be_empty
        end
      end
    end

    context 'with rule_type set to :report_approver' do
      let(:result) { subject.execute }

      context 'without report_type' do
        subject do
          described_class.new(target, user,
            { name: 'License-Check', approvals_required: 1, rule_type: :report_approver })
        end

        specify { expect(result[:status]).to eq(:error) }
      end

      context 'with report_type set to any of valid value' do
        using RSpec::Parameterized::TableSyntax

        subject do
          described_class.new(target, user,
            { name: rule_name, approvals_required: 1, rule_type: :report_approver, report_type: report_type })
        end

        where(:rule_name, :report_type) do
          'License-Check'       | :license_scanning
          'Coverage-Check'      | :code_coverage
        end

        with_them do
          specify { expect(result[:status]).to eq(:success) }
          specify { expect(result[:rule].approvals_required).to eq(1) }
          specify { expect(result[:rule].rule_type).to eq('report_approver') }
        end
      end
    end
  end

  context 'when target is merge request' do
    let_it_be(:target) { create(:merge_request, source_project: project, target_project: project) }

    it_behaves_like "creatable"

    it_behaves_like 'onboarding progress action'

    context 'when project rule id is present' do
      let_it_be(:project_user, freeze: false) { create(:user) }
      let_it_be(:public_group, freeze: false) { create(:group, :public) }

      let(:project_user_approvers) { [project_user] }
      let(:group_user_approvers) { [public_group] }
      let(:merge_request_approvers) { {} }
      let(:project_rule) do
        create(
          :approval_project_rule,
          project: project,
          name: 'bar',
          approvals_required: 1,
          users: project_user_approvers,
          groups: group_user_approvers
        )
      end

      let(:result) do
        described_class.new(target, user, {
          name: 'foo',
          approvals_required: 0,
          approval_project_rule_id: project_rule.id
        }.merge(merge_request_approvers)).execute
      end

      let(:rule) { result[:rule] }

      before_all do
        project.add_developer(project_user)
      end

      it 'associates with project rule and copies its properites' do
        expect(result[:status]).to eq(:success)
        expect(rule.approvals_required).to eq(0)
        expect(rule.approval_project_rule).to eq(project_rule)
        expect(rule.name).to eq(project_rule.name)
        expect(rule.rule_type).to eq('regular')
        expect(rule.users).to match(project_rule.users)
        expect(rule.groups).to match(project_rule.groups)
      end

      context 'when project rule includes no specific approvers' do
        let(:project_user_approvers) { User.none }
        let(:group_user_approvers) { Group.none }

        it 'associates with project rule and copies its properties' do
          expect(result[:status]).to eq(:success)
          expect(rule.approvals_required).to eq(0)
          expect(rule.approval_project_rule).to eq(project_rule)
          expect(rule.name).to eq(project_rule.name)
          expect(rule.rule_type).to eq('any_approver')
          expect(rule.users).to match([])
          expect(rule.groups).to match([])
        end
      end

      context 'when merge request includes empty approvers' do
        let(:merge_request_approvers) do
          {
            user_ids: [],
            group_ids: []
          }
        end

        it 'sets any approver' do
          expect(result[:status]).to eq(:success)
          expect(rule.name).to eq(project_rule.name)
          expect(rule.rule_type).to eq('any_approver')
          expect(rule.users).to eq([])
          expect(rule.groups).to eq([])
        end
      end

      context 'when merge request overrides approvers' do
        let(:merge_request_approvers) { { user_ids: [user.id] } }

        it 'sets single user as the approver' do
          expect(result[:status]).to eq(:success)
          expect(rule.name).to eq(project_rule.name)
          expect(rule.rule_type).to eq('regular')
          expect(rule.users).to eq([user])
          expect(rule.groups).to eq([])
        end
      end

      context 'when project rule is under the same project as MR' do
        let(:another_project) { create(:project) }

        before do
          project_rule.update!(project: another_project)
        end

        it 'ignores assignment' do
          expect(result[:status]).to eq(:success)
          expect(rule.approvals_required).to eq(0)
          expect(rule.approval_project_rule).to eq(nil)
        end

        it 'does not copy properties from project rule' do
          expect(rule.name).to eq('foo')
          expect(rule.users).to be_empty
          expect(rule.groups).to be_empty
        end
      end
    end
  end

  describe 'cross-organization group isolation' do
    let_it_be(:organization) { create(:organization, :isolated) }
    let_it_be(:other_organization) { create(:organization) }
    let_it_be(:isolated_project, freeze: false) { create(:project, organization: organization) }
    let_it_be(:non_isolated_project, freeze: false) { create(:project, organization: other_organization) }
    let_it_be(:same_org_group) { create(:group, :private, organization: organization) }
    let_it_be(:cross_org_group) { create(:group, :private, organization: other_organization) }
    let_it_be(:actor) { create(:user, organization: organization) }

    before_all do
      isolated_project.add_maintainer(actor)
      non_isolated_project.add_maintainer(actor)
      same_org_group.add_developer(actor)
      cross_org_group.add_developer(actor)
    end

    context 'when the organization is isolated' do
      it 'silently filters out groups from a different organization' do
        result = described_class.new(isolated_project, actor, {
          name: 'security',
          approvals_required: 1,
          group_ids: [same_org_group.id, cross_org_group.id]
        }).execute

        expect(result).to be_success
        expect(result[:rule].groups).to contain_exactly(same_org_group)
      end
    end

    context 'when the organization is not isolated' do
      it 'allows groups from any organization' do
        result = described_class.new(non_isolated_project, actor, {
          name: 'security',
          approvals_required: 1,
          group_ids: [cross_org_group.id, same_org_group.id]
        }).execute

        expect(result).to be_success
        expect(result[:rule].groups).to contain_exactly(cross_org_group, same_org_group)
      end
    end
  end

  context 'when audit event is streamed with correct event type', :request_store do
    let_it_be(:user, freeze: false) { create(:user) }
    let_it_be(:group, freeze: false) { create(:group) }
    let_it_be(:project, freeze: false) { create(:project, creator: user, group: group) }
    let_it_be(:new_approvers) { create_list(:user, 2) }
    let_it_be(:new_groups) { create_list(:group, 2, :private) }
    let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }

    subject do
      described_class.new(
        project,
        user,
        { name: 'security',
          approvals_required: 1,
          user_ids: new_approvers.map(&:id),
          group_ids: new_groups.map(&:id) }
      ).execute
    end

    before_all do
      group.add_owner(user)
    end

    before do
      stub_licensed_features(external_audit_events: true)
    end

    it_behaves_like 'sends correct event type in audit event stream' do
      let_it_be(:event_type) { 'approval_rule_created' }
    end
  end
end
