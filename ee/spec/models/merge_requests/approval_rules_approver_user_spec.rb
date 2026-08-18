# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalRulesApproverUser, type: :model, feature_category: :code_review_workflow do
  describe '#set_sharding_key' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let(:approval_rule) { create(:merge_requests_approval_rule, :from_group, group_id: group.id) }

    subject(:approval_rules_approver_user) do
      create(:merge_requests_approval_rules_approver_user, user: user, approval_rule: approval_rule)
    end

    describe '#set_sharding_key' do
      context 'when approval rule origin is group' do
        it 'sets the group_id' do
          expect(approval_rules_approver_user.group_id).to eq(group.id)
        end

        it 'does not set the project_id' do
          expect(approval_rules_approver_user.project_id).to be_nil
        end
      end

      context 'when approval rule origin is not group' do
        let_it_be(:project) { create(:project) }
        let(:origin) { :from_project }
        let(:approval_rule) { create(:merge_requests_approval_rule, origin, project_id: project.id) }

        context 'when approval rule origin is project' do
          it 'sets the project_id' do
            expect(approval_rules_approver_user.project_id).to eq(project.id)
          end

          it 'does not set the group_id' do
            expect(approval_rules_approver_user.group_id).to be_nil
          end
        end

        context 'when approval rule origin is merge request' do
          let(:origin) { :from_merge_request }

          it 'sets the project_id' do
            expect(approval_rules_approver_user.project_id).to eq(project.id)
          end

          it 'does not set the group_id' do
            expect(approval_rules_approver_user.group_id).to be_nil
          end
        end
      end
    end
  end
end
