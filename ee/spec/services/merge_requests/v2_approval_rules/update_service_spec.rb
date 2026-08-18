# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::V2ApprovalRules::UpdateService, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:approver_user1) { create(:user) }
  let_it_be(:approver_user2) { create(:user) }
  let_it_be(:approver_group1) { create(:group) }
  let_it_be(:approver_group2) { create(:group) }
  let_it_be(:hidden_group) { create(:group, :private) }

  let!(:rule) do
    create(:merge_requests_approval_rule,
      sharding_project: project,
      name: 'Original Rule',
      approvals_required: 1
    ).tap do |r|
      create(:merge_requests_approval_rules_merge_request, approval_rule: r, merge_request: merge_request)
    end
  end

  let(:params) { { approval_rule_id: rule.id, name: 'Updated Rule', approvals_required: 3 } }

  subject(:service_response) { described_class.new(merge_request, current_user, params).execute }

  describe '#execute' do
    before_all do
      project.add_maintainer(current_user)
      project.add_developer(approver_user1)
      project.add_developer(approver_user2)
      approver_group1.add_developer(current_user)
      approver_group2.add_developer(current_user)
    end

    it 'returns success and updates the rule attributes' do
      expect(service_response).to be_success

      rule_result = service_response.payload[:rule]
      expect(rule_result).to have_attributes(
        name: 'Updated Rule',
        approvals_required: 3
      )
    end

    context 'with partial updates' do
      let(:params) { { approval_rule_id: rule.id, name: 'New Name Only' } }

      it 'updates only the provided attributes' do
        expect(service_response).to be_success
        expect(service_response.payload[:rule].name).to eq('New Name Only')
      end
    end

    context 'when updating approvals_required only' do
      let(:params) { { approval_rule_id: rule.id, approvals_required: 5 } }

      it 'updates only approvals_required' do
        expect(service_response).to be_success
        expect(service_response.payload[:rule].approvals_required).to eq(5)
      end
    end

    context 'when approvals_required is a string' do
      let(:params) { { approval_rule_id: rule.id, approvals_required: '5' } }

      it 'coerces to integer' do
        expect(service_response).to be_success
        expect(service_response.payload[:rule].approvals_required).to eq(5)
      end
    end

    context 'with approver assignment' do
      let(:params) do
        {
          approval_rule_id: rule.id,
          user_ids: [approver_user1.id, approver_user2.id],
          group_ids: [approver_group1.id, approver_group2.id]
        }
      end

      it 'assigns user and group approvers' do
        rule_result = service_response.payload[:rule]

        expect(rule_result.approver_users).to contain_exactly(approver_user1, approver_user2)
        expect(rule_result.approver_groups).to contain_exactly(approver_group1, approver_group2)
      end
    end

    context 'when replacing existing approvers' do
      let!(:rule_with_approvers) do
        create(:merge_requests_approval_rule,
          sharding_project: project,
          name: 'Replace Test',
          approvals_required: 1
        ).tap do |r|
          create(:merge_requests_approval_rules_merge_request, approval_rule: r, merge_request: merge_request)
          r.approver_users = [approver_user1]
          r.approver_groups = [approver_group1]
        end
      end

      let(:params) do
        {
          approval_rule_id: rule_with_approvers.id,
          user_ids: [approver_user2.id],
          group_ids: [approver_group2.id]
        }
      end

      it 'replaces approvers with the new set' do
        rule_result = service_response.payload[:rule]

        expect(rule_result.approver_users).to contain_exactly(approver_user2)
        expect(rule_result.approver_groups).to contain_exactly(approver_group2)
      end
    end

    context 'when user_ids include non-project members' do
      let(:non_member_user) { create(:user) }
      let(:params) do
        {
          approval_rule_id: rule.id,
          user_ids: [approver_user1.id, non_member_user.id]
        }
      end

      it 'filters out non-members silently' do
        rule_result = service_response.payload[:rule]

        expect(rule_result.approver_users).to contain_exactly(approver_user1)
        expect(rule_result.approver_users).not_to include(non_member_user)
      end
    end

    context 'when group_ids include inaccessible groups' do
      let(:inaccessible_group) { create(:group, :private) }
      let(:params) do
        {
          approval_rule_id: rule.id,
          group_ids: [approver_group1.id, inaccessible_group.id]
        }
      end

      it 'filters out inaccessible groups silently' do
        rule_result = service_response.payload[:rule]

        expect(rule_result.approver_groups).to contain_exactly(approver_group1)
        expect(rule_result.approver_groups).not_to include(inaccessible_group)
      end
    end

    context 'when clearing approvers with empty arrays' do
      let!(:rule_with_approvers) do
        create(:merge_requests_approval_rule,
          sharding_project: project,
          name: 'Clear Test',
          approvals_required: 1
        ).tap do |r|
          create(:merge_requests_approval_rules_merge_request, approval_rule: r, merge_request: merge_request)
          r.approver_users = [approver_user1]
          r.approver_groups = [approver_group1]
        end
      end

      let(:params) { { approval_rule_id: rule_with_approvers.id, user_ids: [], group_ids: [] } }

      it 'removes all approvers' do
        rule_result = service_response.payload[:rule]

        expect(rule_result.approver_users).to be_empty
        expect(rule_result.approver_groups).to be_empty
      end
    end

    context 'when approver ids are not provided' do
      let!(:rule_with_approvers) do
        create(:merge_requests_approval_rule,
          sharding_project: project,
          name: 'Preserve Test',
          approvals_required: 1
        ).tap do |r|
          create(:merge_requests_approval_rules_merge_request, approval_rule: r, merge_request: merge_request)
          r.approver_users = [approver_user1]
        end
      end

      let(:params) { { approval_rule_id: rule_with_approvers.id, name: 'Updated' } }

      it 'does not change existing approvers' do
        rule_result = service_response.payload[:rule]

        expect(rule_result.approver_users).to contain_exactly(approver_user1)
      end
    end

    context 'with non-existent approver ids' do
      let(:non_existing_user_id) { User.maximum(:id).to_i + 1 }
      let(:non_existing_group_id) { Group.maximum(:id).to_i + 1 }

      it 'ignores non-existent users and keeps valid ones' do
        params[:user_ids] = [approver_user1.id, non_existing_user_id]
        params[:group_ids] = [approver_group1.id, non_existing_group_id]

        rule_result = service_response.payload[:rule]
        expect(rule_result.approver_users).to contain_exactly(approver_user1)
        expect(rule_result.approver_groups).to contain_exactly(approver_group1)
      end

      it 'assigns empty approvers when all ids are invalid' do
        params[:user_ids] = [non_existing_user_id]
        params[:group_ids] = [non_existing_group_id]

        rule_result = service_response.payload[:rule]
        expect(rule_result.approver_users).to be_empty
        expect(rule_result.approver_groups).to be_empty
      end
    end

    context 'with duplicate approver ids' do
      let(:params) do
        {
          approval_rule_id: rule.id,
          user_ids: [approver_user1.id, approver_user1.id],
          group_ids: [approver_group1.id, approver_group1.id]
        }
      end

      it 'associates each approver only once' do
        rule_result = service_response.payload[:rule]

        expect(rule_result.approver_users).to contain_exactly(approver_user1)
        expect(rule_result.approver_groups).to contain_exactly(approver_group1)
      end
    end

    context 'with remove_hidden_groups' do
      let!(:rule_with_hidden_group) do
        create(:merge_requests_approval_rule,
          sharding_project: project,
          name: 'Hidden Groups Test',
          approvals_required: 1
        ).tap do |r|
          create(:merge_requests_approval_rules_merge_request, approval_rule: r, merge_request: merge_request)
          r.approver_groups = [approver_group1, hidden_group]
        end
      end

      context 'when remove_hidden_groups is false (default)' do
        let(:params) do
          { approval_rule_id: rule_with_hidden_group.id, group_ids: [approver_group2.id] }
        end

        it 'keeps hidden groups alongside new groups' do
          rule_result = service_response.payload[:rule]

          expect(rule_result.approver_groups).to contain_exactly(approver_group2, hidden_group)
        end
      end

      context 'when remove_hidden_groups is true' do
        let(:params) do
          { approval_rule_id: rule_with_hidden_group.id, group_ids: [approver_group2.id], remove_hidden_groups: 'true' }
        end

        it 'removes hidden groups' do
          rule_result = service_response.payload[:rule]

          expect(rule_result.approver_groups).to contain_exactly(approver_group2)
        end
      end
    end

    context 'when rule belongs to different merge request' do
      let(:other_merge_request) do
        create(:merge_request, :unique_branches, source_project: project, target_project: project)
      end

      let!(:other_rule) do
        create(:merge_requests_approval_rule,
          sharding_project: project,
          name: 'Other MR Rule',
          approvals_required: 2
        ).tap do |r|
          create(:merge_requests_approval_rules_merge_request, approval_rule: r, merge_request: other_merge_request)
        end
      end

      let(:params) { { approval_rule_id: other_rule.id, name: 'Hacked Name' } }

      it 'returns rule not found error' do
        expect(service_response).to be_error
        expect(service_response.message).to eq('Rule not found')
      end

      it 'does not update the other rule' do
        service_response

        expect(other_rule.reload.name).to eq('Other MR Rule')
      end
    end

    context 'with no attributes to update' do
      let(:params) { { approval_rule_id: rule.id } }

      it 'succeeds without issuing an update' do
        expect(service_response).to be_success
        expect(service_response.payload[:rule]).to eq(rule)
      end
    end

    context 'when rule is not found' do
      let(:params) { { approval_rule_id: non_existing_record_id } }

      it 'returns error' do
        expect(service_response).to be_error
        expect(service_response.message).to eq('Rule not found')
      end
    end

    context 'with validation errors' do
      it 'returns error when name is blank' do
        result = described_class.new(merge_request, current_user, { approval_rule_id: rule.id, name: '' }).execute

        expect(result).to be_error
        expect(result.message).to include("can't be blank")
      end

      it 'returns error when name exceeds 255 characters' do
        params = { approval_rule_id: rule.id, name: 'a' * 256 }
        result = described_class.new(merge_request, current_user, params).execute

        expect(result).to be_error
        expect(result.message).to include('too long')
      end

      it 'returns error when approvals_required is negative' do
        result = described_class.new(
          merge_request, current_user, { approval_rule_id: rule.id, approvals_required: -1 }
        ).execute

        expect(result).to be_error
        expect(result.message).to include('greater than or equal to 0')
      end

      it 'does not modify the rule on validation failure' do
        original_name = rule.reload.name
        params = { approval_rule_id: rule.id, name: '', approvals_required: 5 }
        described_class.new(merge_request, current_user, params).execute

        expect(rule.reload.name).to eq(original_name)
      end
    end

    context 'when database transaction fails' do
      context 'when update! raises' do
        before do
          allow_next_found_instance_of(MergeRequests::ApprovalRule) do |instance|
            allow(instance).to receive(:update!).and_raise(
              ActiveRecord::RecordInvalid.new(instance)
            )
          end
        end

        it 'returns error with validation messages' do
          expect(service_response).to be_error
          expect(service_response.message).to be_a(Hash)
          expect(service_response.payload[:rule]).to eq(rule)
        end
      end

      context 'when approver association fails' do
        let(:params) { { approval_rule_id: rule.id, user_ids: [approver_user1.id] } }

        before do
          allow_next_found_instance_of(MergeRequests::ApprovalRule) do |instance|
            allow(instance).to receive(:approver_users=).and_raise(ActiveRecord::RecordInvalid.new(instance))
          end
        end

        it 'rolls back all changes' do
          original_name = rule.name
          params[:name] = 'Should Not Persist'

          service_response

          expect(rule.reload.name).to eq(original_name)
        end
      end
    end

    context 'when user does not have permission' do
      let_it_be(:non_member) { create(:user) }

      subject(:service_response) { described_class.new(merge_request, non_member, params).execute }

      it 'returns access denied error' do
        expect(service_response).to be_error
        expect(service_response.reason).to eq(:access_denied)
      end
    end
  end
end
