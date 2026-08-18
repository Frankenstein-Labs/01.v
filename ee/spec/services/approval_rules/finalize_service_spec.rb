# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::FinalizeService, feature_category: :code_review_workflow do
  let(:project) { create(:project, :repository) }
  let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  describe '#execute' do
    let_it_be(:user1) { create(:user) }
    let_it_be(:user2) { create(:user) }
    let_it_be(:user3) { create(:user) }
    let_it_be(:group1) { create(:group) }
    let_it_be(:group2) { create(:group) }
    let_it_be(:group1_user) { create(:user) }
    let_it_be(:group2_user) { create(:user) }
    let!(:approval1) { create(:approval, merge_request: merge_request, user: user1) }
    let!(:approval2) { create(:approval, merge_request: merge_request, user: user3) }
    let!(:approval3) { create(:approval, merge_request: merge_request, user: group1_user) }
    let!(:approval4) { create(:approval, merge_request: merge_request, user: group2_user) }
    let!(:project_rule) { create(:approval_project_rule, project: project, name: 'foo', approvals_required: 12) }

    subject { described_class.new(merge_request) }

    before_all do
      group1.add_guest(group1_user)
      group2.add_guest(group2_user)
    end

    before do
      project_rule.users = [user1, user2]
      project_rule.groups << group1
    end

    context 'when approval rules are overwritten' do
      before do
        rule = create(:approval_merge_request_rule, merge_request: merge_request, name: 'applicable',
          approvals_required: 32)
        rule.users = [user2, user3]
        rule.groups << group2

        rule_2 = create(:approval_merge_request_rule, merge_request: merge_request, name: 'not applicable',
          approvals_required: 2)
        rule_2.groups << group2

        protected_rule = create(:approval_project_rule, project: project, name: 'not applicable', approvals_required: 2)

        create(:approval_project_rules_protected_branch, approval_project_rule: protected_rule)

        create(:approval_merge_request_rule_source, approval_merge_request_rule: rule_2, approval_project_rule:
               protected_rule)

        project.update!(disable_overriding_approvers_per_merge_request: false)
      end

      context 'when mr is not merged' do
        it 'does nothing' do
          expect do
            subject.execute
          end.not_to change { ApprovalMergeRequestRule.count }
        end
      end

      context 'when mr is merged' do
        context 'when the code owner rule is required' do
          let!(:mr_code_owner_rule) { create(:code_owner_rule, merge_request: merge_request, approvals_required: 5) }

          it 'updates the approvals_required accordingly' do
            merge_request.mark_as_merged!

            expect { subject.execute }.to change { mr_code_owner_rule.reload.approvals_required }.from(5).to(0)
          end
        end

        it 'does not copy project rules, and updates approval mapping with MR rules' do
          merge_request.mark_as_merged!

          expect do
            subject.execute
          end.not_to change { ApprovalMergeRequestRule.count }

          expect(merge_request.approval_rules.regular.count).to eq(2)

          applicable_rule = merge_request.approval_rules.regular.first

          expect(applicable_rule.name).to eq('applicable')
          expect(applicable_rule.approvals_required).to eq(32)
          expect(applicable_rule.users).to contain_exactly(user2, user3, group2_user)
          expect(applicable_rule.groups).to contain_exactly(group2)
          expect(applicable_rule.rule_type).not_to be_nil
          expect(applicable_rule.applicable_post_merge).to be_truthy
          expect(applicable_rule.approved_approvers).to contain_exactly(user3, group2_user)

          non_applicable_rule = merge_request.approval_rules.regular.second

          expect(non_applicable_rule.name).to eq('not applicable')
          expect(non_applicable_rule.approvals_required).to eq(2)
          expect(non_applicable_rule.users).to contain_exactly(group2_user)
          expect(non_applicable_rule.groups).to contain_exactly(group2)
          expect(non_applicable_rule.rule_type).not_to be_nil
          expect(non_applicable_rule.applicable_post_merge).to be_falsey
          expect(non_applicable_rule.approved_approvers).to contain_exactly(group2_user)
        end

        # Test for https://gitlab.com/gitlab-org/gitlab/issues/13488
        it 'gracefully merges duplicate users' do
          merge_request.mark_as_merged!

          group2.add_developer(user2)

          expect do
            subject.execute
          end.not_to change { ApprovalMergeRequestRule.count }

          rule = merge_request.approval_rules.regular.first

          expect(rule.name).to eq('applicable')
          expect(rule.users).to contain_exactly(user2, user3, group2_user)
        end
      end
    end

    context 'when approval rules are not overwritten' do
      let!(:any_approver) do
        create(:approval_project_rule, project: project, name: 'hallo', approvals_required: 45,
          rule_type: :any_approver)
      end

      let!(:protected_branch) do
        create(:approval_project_rules_protected_branch, approval_project_rule: protected_rule)
      end

      let(:protected_rule) do
        create(:approval_project_rule, project: project, name: 'other_branch', approvals_required: 32)
      end

      let!(:reporter_rule) do
        create(:approval_project_rule, :license_scanning, project: project, name: 'reporter_branch',
          approvals_required: 21)
      end

      let!(:mr_code_owner_rule) { create(:code_owner_rule, merge_request: merge_request) }
      let!(:non_appl_report_rule) do
        rule = create(:report_approver_rule, :license_scanning, merge_request: merge_request, name: 'not applicable',
          approvals_required: 2)

        protected_rule = create(:approval_project_rule, :license_scanning, project: project, name: 'not applicable',
          approvals_required: 2)

        create(:approval_project_rules_protected_branch, approval_project_rule: protected_rule)

        create(:approval_merge_request_rule_source, approval_merge_request_rule: rule, approval_project_rule:
               protected_rule)

        rule
      end

      before do
        project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      context 'when mr is not merged' do
        it 'does nothing' do
          expect do
            subject.execute
          end.not_to change { ApprovalMergeRequestRule.count }
        end
      end

      context 'when mr is merged' do
        let(:expected_rules) do
          {
            regular: {
              required: 12,
              name: "foo",
              users: [user1, user2, group1_user],
              groups: [group1],
              approvers: [user1, group1_user],
              rule_type: 'regular',
              report_type: nil,
              applicable_post_merge: true
            },
            any_approver: {
              required: 45,
              name: "hallo",
              users: [],
              groups: [],
              approvers: [user1, user3, group1_user, group2_user],
              rule_type: 'any_approver',
              report_type: nil,
              applicable_post_merge: true
            },
            non_applicable: {
              required: 32,
              name: "other_branch",
              users: [],
              groups: [],
              approvers: [],
              rule_type: 'regular',
              applicable_post_merge: false
            }
          }
        end

        context 'when the code owner rule is required' do
          let!(:mr_code_owner_rule) { create(:code_owner_rule, merge_request: merge_request, approvals_required: 5) }

          it 'updates the approvals_required accordingly' do
            merge_request.mark_as_merged!

            expect { subject.execute }.to change { mr_code_owner_rule.reload.approvals_required }.from(5).to(0)
          end
        end

        it 'copies the expected rules with expected params' do
          expect(mr_code_owner_rule.applicable_post_merge).to eq(nil)
          expect(non_appl_report_rule.applicable_post_merge).to eq(nil)

          merge_request.mark_as_merged!

          expect do
            subject.execute
          end.to change { ApprovalMergeRequestRule.count }.by(3)

          expect(mr_code_owner_rule.reload.applicable_post_merge).to eq(true)
          expect(mr_code_owner_rule.approvals_required).to eq(0)
          expect(non_appl_report_rule.reload.applicable_post_merge).to eq(false)
          expect(merge_request.approval_rules.size).to eq(5)

          expected_rules.each do |_key, hash|
            rule = merge_request.approval_rules.find_by(name: hash[:name])

            expect(rule).to be_truthy
            expect(rule.rule_type).to eq(hash[:rule_type])
            expect(rule.approvals_required).to eq(hash[:required])
            expect(rule.report_type).to eq(hash[:report_type])
            expect(rule.applicable_post_merge).to eq(hash[:applicable_post_merge])
            expect(rule.users).to contain_exactly(*hash[:users])
            expect(rule.groups).to contain_exactly(*hash[:groups])
            expect(rule.approved_approvers).to contain_exactly(*hash[:approvers])
          end
        end

        context 'when the same merge request rule exists in the project rules' do
          it 'logs the validation error and sets the merge rule to not applicable post merge' do
            rule_2 = create(:approval_merge_request_rule, merge_request: merge_request, name: 'not applicable')

            protected_rule = create(:approval_project_rule, project: project, name: 'not applicable')

            create(:approval_project_rules_protected_branch, approval_project_rule: protected_rule)

            create(:approval_merge_request_rule_source, approval_merge_request_rule: rule_2, approval_project_rule:
                   protected_rule)

            merge_request.mark_as_merged!

            expect(Gitlab::AppLogger).to receive(:debug).with(/Failed to persist approval rule:/)

            expect(rule_2.applicable_post_merge).to eq(nil)

            expect do
              subject.execute
            end.to change { ApprovalMergeRequestRule.count }.by(3)

            expect(rule_2.reload.applicable_post_merge).to eq(false)
          end
        end
      end
    end
  end
end
