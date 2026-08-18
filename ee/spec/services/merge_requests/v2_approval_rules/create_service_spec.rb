# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::V2ApprovalRules::CreateService, feature_category: :code_review_workflow do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:approver_user1) { create(:user) }
  let_it_be(:approver_user2) { create(:user) }
  let_it_be(:approver_group1) { create(:group, developers: current_user) }
  let_it_be(:approver_group2) { create(:group, developers: current_user) }
  let_it_be(:project) { create(:project, maintainers: current_user, developers: [approver_user1, approver_user2]) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  let(:params) do
    {
      name: 'Security Team',
      approvals_required: 2,
      rule_type: :regular,
      user_ids: [approver_user1.id, approver_user2.id],
      group_ids: [approver_group1.id, approver_group2.id]
    }
  end

  subject(:service_response) { described_class.new(merge_request, current_user, params).execute }

  describe '#execute' do
    it 'returns success and creates an approval rule with correct attributes' do
      expect(service_response).to be_success

      rule = service_response.payload[:rule]
      expect(rule).to be_persisted
      expect(rule).to have_attributes(
        name: 'Security Team',
        approvals_required: 2,
        rule_type: 'regular',
        origin: 'merge_request'
      )
    end

    it 'associates user and group approvers' do
      rule = service_response.payload[:rule]

      expect(rule.approver_users).to contain_exactly(approver_user1, approver_user2)
      expect(rule.approver_groups).to contain_exactly(approver_group1, approver_group2)
    end

    it 'creates join record with correct sharding key' do
      expect { service_response }.to change { MergeRequests::ApprovalRulesMergeRequest.count }.by(1)

      join_record = MergeRequests::ApprovalRulesMergeRequest.last
      expect(join_record).to have_attributes(
        approval_rule: service_response.payload[:rule],
        merge_request: merge_request,
        project_id: project.id
      )
    end

    context 'with rule_type variations' do
      where(:rule_type) { %i[code_owner report_approver any_approver] }

      with_them do
        let(:params) { { name: 'Typed Rule', approvals_required: 1, rule_type: rule_type } }

        it 'creates approval rule with the specified type' do
          expect(service_response.payload[:rule].rule_type).to eq(rule_type.to_s)
        end
      end
    end

    context 'with default values' do
      let(:params) { { name: 'Minimal Rule' } }

      it 'defaults rule_type to regular and approvals_required to 0' do
        rule = service_response.payload[:rule]

        expect(rule.rule_type).to eq('regular')
        expect(rule.approvals_required).to eq(0)
      end
    end

    context 'without approver ids' do
      let(:params) { { name: 'No Approvers', approvals_required: 1 } }

      it 'creates rule with no approvers' do
        rule = service_response.payload[:rule]

        expect(rule.approver_users).to be_empty
        expect(rule.approver_groups).to be_empty
      end
    end

    context 'with non-existent approver ids' do
      let(:non_existing_user_id) { User.maximum(:id).to_i + 1 }
      let(:non_existing_group_id) { Group.maximum(:id).to_i + 1 }

      it 'ignores non-existent users and keeps valid ones' do
        params[:user_ids] = [approver_user1.id, non_existing_user_id]
        params[:group_ids] = [approver_group1.id, non_existing_group_id]

        rule = service_response.payload[:rule]
        expect(rule.approver_users).to contain_exactly(approver_user1)
        expect(rule.approver_groups).to contain_exactly(approver_group1)
      end

      it 'creates rule with no approvers when all ids are invalid' do
        params[:user_ids] = [non_existing_user_id]
        params[:group_ids] = [non_existing_group_id]

        rule = service_response.payload[:rule]
        expect(rule.approver_users).to be_empty
        expect(rule.approver_groups).to be_empty
      end
    end

    context 'with duplicate approver ids' do
      let(:params) do
        {
          name: 'Duplicates',
          approvals_required: 1,
          user_ids: [approver_user1.id, approver_user1.id],
          group_ids: [approver_group1.id, approver_group1.id]
        }
      end

      it 'associates each approver only once' do
        rule = service_response.payload[:rule]

        expect(rule.approver_users).to contain_exactly(approver_user1)
        expect(rule.approver_groups).to contain_exactly(approver_group1)
      end
    end

    context 'with validation errors' do
      it 'returns error when name is missing' do
        result = described_class.new(merge_request, current_user, { approvals_required: 1 }).execute

        expect(result).to be_error
        expect(result.message).to include("can't be blank")
      end

      it 'returns error when name exceeds 255 characters' do
        result = described_class.new(merge_request, current_user, { name: 'a' * 256 }).execute

        expect(result).to be_error
        expect(result.message).to include('too long')
      end

      it 'returns error when approvals_required is negative' do
        result = described_class.new(merge_request, current_user, { name: 'Rule', approvals_required: -1 }).execute

        expect(result).to be_error
        expect(result.message).to include('greater than or equal to 0')
      end

      it 'returns error when rule_type is invalid' do
        result = described_class.new(merge_request, current_user, { name: 'Rule', rule_type: 'invalid_type' }).execute

        expect(result).to be_error
        expect(result.message).to include('not a valid rule_type')
      end

      it 'does not create any records on validation failure' do
        rule_count = MergeRequests::ApprovalRule.count
        join_count = MergeRequests::ApprovalRulesMergeRequest.count

        described_class.new(merge_request, current_user, { approvals_required: 1 }).execute

        expect(MergeRequests::ApprovalRule.count).to eq(rule_count)
        expect(MergeRequests::ApprovalRulesMergeRequest.count).to eq(join_count)
      end
    end

    context 'when database transaction fails' do
      context 'when approver association fails' do
        before do
          allow_next_instance_of(MergeRequests::ApprovalRule) do |instance|
            allow(instance).to receive(:approver_users=).and_raise(ActiveRecord::RecordInvalid)
          end
        end

        it 'rolls back all changes' do
          expect { service_response }.not_to change { MergeRequests::ApprovalRule.count }
        end
      end
    end
  end
end
