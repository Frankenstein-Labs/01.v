# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalRule, type: :model, feature_category: :code_review_workflow do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let(:attributes) { {} }

  subject(:rule) { build(:merge_requests_approval_rule, attributes) }

  describe 'user_defined?' do
    using RSpec::Parameterized::TableSyntax

    where(:rule_type, :expected_result) do
      :regular        | true
      :any_approver   | true
      :code_owner     | false
      :report_approver | false
    end

    with_them do
      subject(:user_defined) { build(:merge_requests_approval_rule, rule_type: rule_type).user_defined? }

      it "returns #{params[:expected_result]} for #{params[:rule_type]} rule type" do
        expect(user_defined).to eq(expected_result)
      end
    end
  end

  describe 'validations' do
    describe 'sharding key validation' do
      context 'with group_id' do
        let(:attributes) { { group_id: group.id } }

        it { is_expected.to be_valid }
      end

      context 'with project_id' do
        let(:attributes) { { project_id: project.id } }

        it { is_expected.to be_valid }
      end

      context 'without project_id or group_id' do
        subject(:rule) { described_class.new(name: 'Test Rule', approvals_required: 2) }

        it { is_expected.not_to be_valid }

        it 'has the correct error message' do
          rule.valid?
          expect(rule.errors[:base]).to contain_exactly('Exactly one of group_id, project_id must be present')
        end
      end

      context 'with both project_id and group_id' do
        subject(:rule) do
          described_class.new(
            name: 'Test Rule',
            approvals_required: 2,
            project_id: project.id,
            group_id: group.id
          )
        end

        it { is_expected.not_to be_valid }

        it 'has the correct error message' do
          rule.valid?
          expect(rule.errors[:base]).to contain_exactly('Exactly one of group_id, project_id must be present')
        end
      end
    end
  end

  describe 'associations' do
    # Multiple groups associations
    it { is_expected.to have_many(:approval_rules_groups) }
    it { is_expected.to have_many(:source_groups).through(:approval_rules_groups) }

    # Single group associations
    it { is_expected.to have_one(:approval_rules_group).inverse_of(:approval_rule) }
    it { is_expected.to have_one(:source_group).through(:approval_rules_group) }

    # Multiple projects associations
    it { is_expected.to have_many(:approval_rules_projects) }
    it { is_expected.to have_many(:projects).through(:approval_rules_projects) }

    # Single project associations
    it { is_expected.to have_one(:approval_rules_project) }
    it { is_expected.to have_one(:project).through(:approval_rules_project) }

    # Multiple merge requests associations
    it { is_expected.to have_many(:approval_rules_merge_requests) }
    it { is_expected.to have_many(:merge_requests).through(:approval_rules_merge_requests) }

    # Single merge request associations
    it { is_expected.to have_one(:approval_rules_merge_request).inverse_of(:approval_rule) }
    it { is_expected.to have_one(:merge_request).through(:approval_rules_merge_request) }

    # Approver users associations
    it { is_expected.to have_many(:approval_rules_approver_users) }
    it { is_expected.to have_many(:approver_users).through(:approval_rules_approver_users).source(:user) }

    # Approver groups associations
    it { is_expected.to have_many(:approval_rules_approver_groups) }
    it { is_expected.to have_many(:approver_groups).through(:approval_rules_approver_groups).source(:group) }

    # Group users association
    it { is_expected.to have_many(:group_users).through(:approver_groups).source(:users) }
  end

  describe 'group_users association' do
    let(:parent_group) { create(:group) }
    let(:approval_rule) { create(:merge_requests_approval_rule, group_id: parent_group.id) }
    let(:group1) { create(:group) }
    let(:group2) { create(:group) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }

    before do
      # Add groups as approver groups
      create(:merge_requests_approval_rules_approver_group, approval_rule: approval_rule, group: group1)
      create(:merge_requests_approval_rules_approver_group, approval_rule: approval_rule, group: group2)

      # Add users to groups
      group1.add_developer(user1)
      group1.add_developer(user2)
      group2.add_developer(user2) # user2 is in both groups
      group2.add_developer(user3)
    end

    it 'returns all distinct users from all approver groups' do
      # Verify correct content
      expect(approval_rule.group_users).to contain_exactly(user1, user2, user3)

      # Verify distinct behavior (user2 is in both groups but appears only once)
      expect(approval_rule.group_users.count).to eq(3)
      expect(approval_rule.group_users.where(id: user2.id).count).to eq(1)
    end
  end

  describe '#approver_users' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let(:approval_rule) { create(:merge_requests_approval_rule, :from_group, group_id: group.id) }

    before do
      create(:merge_requests_approval_rules_approver_user,
        user: user,
        approval_rule: approval_rule,
        project_id: approval_rule.project_id)
    end

    it 'returns users through the approval_rules_approver_users association' do
      expect(approval_rule.approver_users).to include(user)
    end
  end

  describe '#approvers' do
    # Common setup for all approvers tests
    let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

    let(:rule) do
      create(
        :merge_requests_approval_rule,
        merge_request: merge_request,
        project_id: project.id
      )
    end

    shared_examples 'approvers contains the right users' do
      it 'contains users as direct members and group members' do
        expect(rule.approvers).to match_array(expected_approvers)
      end

      context 'when some users are inactive' do
        before do
          inactive_users.each(&:block!)
        end

        it 'returns users that are only active' do
          refreshed_rule = described_class.find(rule.id)
          expect(refreshed_rule.approvers).to match_array(active_users)
        end
      end
    end

    context 'with direct approvers and approver groups' do
      let(:user1) { create(:user) }
      let(:user2) { create(:user) }
      let(:group1) { create(:group) }
      let(:group2) { create(:group) }
      let(:group1_user) { create(:user) }
      let(:group2_user) { create(:user) }

      let(:expected_approvers) { [user1, user2, group1_user, group2_user] }
      let(:inactive_users) { [user2, group2_user] }
      let(:active_users) { [user1, group1_user] }

      before do
        # Add approver users with project_id
        create(:merge_requests_approval_rules_approver_user,
          user: user1,
          approval_rule: rule,
          project_id: project.id)

        create(:merge_requests_approval_rules_approver_user,
          user: user2,
          approval_rule: rule,
          project_id: project.id)

        # Add approver groups
        create(:merge_requests_approval_rules_approver_group,
          group: group1,
          approval_rule: rule)

        create(:merge_requests_approval_rules_approver_group,
          group: group2,
          approval_rule: rule)

        # Add users to groups
        group1.add_guest(group1_user)
        group2.add_guest(group2_user)

        # Ensure project settings for author approval
        project.update!(merge_requests_author_approval: false)
      end

      it_behaves_like 'approvers contains the right users'

      context 'when the rules users have already been loaded' do
        before do
          rule.approver_users.to_a
          rule.group_users.to_a
        end

        it 'does not perform any new queries when all users are loaded already' do
          # single query is triggered for license check
          expect { rule.approvers }.not_to exceed_query_limit(1)
        end

        it_behaves_like 'approvers contains the right users'
      end

      context 'when user is both a direct member and a group member' do
        before do
          group1.add_guest(user1)
          group2.add_guest(user2)
        end

        it 'contains only unique users' do
          refreshed_rule = described_class.find(rule.id)
          expect(refreshed_rule.approvers).to match_array(expected_approvers)
        end
      end
    end

    # There is a spec for this behavior in
    # ee/spec/models/concerns/approval_rule_like_spec.rb we can reference when we implement policy
    context 'when scan_result_policy_read has role_approvers' do
      pending "policy implementation"
    end
  end

  describe '#scan_result_policy_read' do
    it 'returns nil' do
      expect(rule.scan_result_policy_read).to be_nil
    end
  end

  describe '#section' do
    it 'returns nil' do
      expect(rule.section).to be_nil
    end
  end

  describe '#users' do
    it 'returns the same result as approver_users' do
      expect(rule.users).to eq(rule.approver_users)
    end
  end

  describe '#groups' do
    it 'returns the same result as approver_groups' do
      expect(rule.groups).to eq(rule.approver_groups)
    end
  end

  describe '#source_rule' do
    it 'returns nil' do
      expect(rule.source_rule).to be_nil
    end
  end

  describe '#overridden?' do
    it 'returns nil' do
      expect(rule.overridden?).to be false
    end
  end

  describe '#code_owner' do
    it 'returns nil' do
      expect(rule.code_owner).to be_nil
    end
  end

  describe '#from_scan_result_policy?' do
    it 'is false' do
      expect(rule.from_scan_result_policy?).to be false
    end
  end

  describe '#warn_mode_policy?' do
    it 'is false' do
      expect(rule.warn_mode_policy?).to be false
    end
  end

  describe '#report_type' do
    it 'is nil' do
      expect(rule.report_type).to be_nil
    end
  end

  describe '#rule_project' do
    subject { rule.rule_project }

    context 'when rule originates from merge request' do
      let(:merge_request) { create(:merge_request) }
      let(:rule) do
        create(:merge_requests_approval_rule,
          merge_request: merge_request,
          project_id: merge_request.project.id,
          origin: :merge_request
        )
      end

      it { is_expected.to eq(merge_request.project) }
    end

    context 'when rule originates from a project' do
      let(:rule) do
        create(:merge_requests_approval_rule,
          :from_project,
          project: project,
          project_id: project.id
        )
      end

      it { is_expected.to eq(project) }
    end

    context 'when rule originates from a group' do
      let(:rule) do
        create(:merge_requests_approval_rule, :from_group, group_id: group.id)
      end

      it { is_expected.to be_nil }
    end
  end
end
