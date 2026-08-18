# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::UserRulesDestroyService, feature_category: :code_review_workflow do
  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }

  let_it_be(:group) { create(:group) }
  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group) }

  let_it_be_with_reload(:merge_request1) do
    create(:merge_request, source_project: project1, target_project: project1)
  end

  let_it_be(:merge_request2) { create(:merge_request, source_project: project2, target_project: project2) }

  let_it_be(:removed_user_ids) { [user1.id] }
  let_it_be(:all_user_ids) { [user1.id, user2.id] }

  describe '#execute' do
    let_it_be(:project_rule) { create(:approval_project_rule, project: project1, user_ids: all_user_ids) }
    let_it_be(:project_rule_other_project) { create(:approval_project_rule, project: project2, user_ids: all_user_ids) }

    subject(:execute) { described_class.new(project: project1).execute(removed_user_ids) }

    it 'destroys related project rule users' do
      expect { execute }.to change { project_rule.users.count }.by(-1)
        .and not_change { project_rule_other_project.users.count }
      expect(project_rule.reload.users).to contain_exactly(user2)
      expect(project_rule_other_project.reload.users).to contain_exactly(user1, user2)
    end

    context 'when there are merge request rules' do
      let_it_be(:merge_request_rule_with_project_rule) do
        create(:approval_merge_request_rule, merge_request: merge_request1, approval_project_rule: project_rule,
          user_ids: all_user_ids)
      end

      let_it_be(:merge_request_rule_without_project_rule) do
        create(:approval_merge_request_rule, merge_request: merge_request1, user_ids: all_user_ids)
      end

      let_it_be(:merge_request_rule_other_project) do
        create(:approval_merge_request_rule, merge_request: merge_request2, user_ids: all_user_ids)
      end

      context 'when open' do
        it 'destroys related merge request rule users' do
          expect { execute }.to change { merge_request_rule_with_project_rule.users.count }.by(-1)
            .and(change { merge_request_rule_without_project_rule.users.count }.by(-1))
          expect(merge_request_rule_with_project_rule.reload.users).to contain_exactly(user2)
          expect(merge_request_rule_without_project_rule.reload.users).to contain_exactly(user2)
          expect(merge_request_rule_other_project.reload.users).to contain_exactly(user1, user2)
        end
      end

      context 'when merged' do
        before do
          merge_request1.mark_as_merged!
        end

        it 'does nothing' do
          expect { execute }.not_to change { ApprovalMergeRequestRulesUser.count }
        end
      end
    end
  end
end
