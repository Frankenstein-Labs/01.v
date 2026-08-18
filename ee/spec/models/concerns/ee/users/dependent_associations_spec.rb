# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Users::DependentAssociations, feature_category: :user_management do
  describe 'associations' do
    let(:user) { create(:user) }
    let(:associations_with_nullify) do
      {
        security_policy_dismissals: { class_name: 'Security::PolicyDismissal' },
        approval_policy_merge_request_bypass_events: { class_name: 'Security::ApprovalPolicyMergeRequestBypassEvent' },
        created_custom_fields: { class_name: 'Issuables::CustomField' },
        updated_custom_fields: { class_name: 'Issuables::CustomField' },
        created_lifecycles: { class_name: 'WorkItems::Statuses::Custom::Lifecycle' },
        updated_lifecycles: { class_name: 'WorkItems::Statuses::Custom::Lifecycle' },
        created_statuses: { class_name: 'WorkItems::Statuses::Custom::Status' },
        updated_statuses: { class_name: 'WorkItems::Statuses::Custom::Status' }
      }
    end

    let(:associations_with_destroy) do
      {
        ai_user_metrics: { foreign_key: :user_id, class_name: 'Ai::UserMetrics' },
        board_assignees: { foreign_key: :assignee_id, class_name: 'BoardAssignee' },
        approval_group_rules_users: { class_name: 'ApprovalRules::ApprovalGroupRulesUser' },
        approval_merge_request_rules_approved_approvers:
          { class_name: 'ApprovalRules::ApprovalMergeRequestRulesApprovedApprover' },
        approval_merge_request_rules_users: {},
        approval_project_rules_users: {},
        duo_workflows_workflows: { class_name: 'Ai::DuoWorkflows::Workflow' },
        lists: {},
        merge_requests_approval_rules_approver_users: { class_name: 'MergeRequests::ApprovalRulesApproverUser' },
        targeted_message_dismissals: {},
        boards_epic_list_user_preferences: { class_name: 'Boards::EpicListUserPreference' },
        security_orchestration_policy_rule_schedules: { class_name: 'Security::OrchestrationPolicyRuleSchedule' }
      }
    end

    it 'defines all expected associations with nullify dependency', :aggregate_failures do
      associations_with_nullify.each do |association_name, options|
        association = ::User.reflect_on_association(association_name)

        expect(association).not_to be_nil, "Expected #{association_name} association to be defined"
        expect(association.options[:dependent]).to eq(:nullify),
          "Expected #{association_name} to have dependent: :nullify"

        if options[:foreign_key]
          expect(association.options[:foreign_key]).to eq(options[:foreign_key]),
            "Expected #{association_name} to have foreign_key: #{options[:foreign_key]}"
        end

        if options[:class_name]
          expect(association.options[:class_name]).to eq(options[:class_name]),
            "Expected #{association_name} to have class_name: #{options[:class_name]}"
        end
      end
    end

    it 'defines all expected associations with destroy dependency', :aggregate_failures do
      associations_with_destroy.each do |association_name, options|
        association = ::User.reflect_on_association(association_name)

        expect(association).not_to be_nil, "Expected #{association_name} association to be defined"
        expect(association.options[:dependent]).to eq(:destroy),
          "Expected #{association_name} to have dependent: :destroy"

        if options[:foreign_key]
          expect(association.options[:foreign_key]).to eq(options[:foreign_key]),
            "Expected #{association_name} to have foreign_key: #{options[:foreign_key]}"
        end

        if options[:class_name]
          expect(association.options[:class_name]).to eq(options[:class_name]),
            "Expected #{association_name} to have class_name: #{options[:class_name]}"
        end
      end
    end
  end

  describe 'association behavior' do
    let(:user) { create(:user) }

    context 'with nullify dependency' do
      it 'nullifies security_policy_dismissals when user is destroyed' do
        dismissal = create(:policy_dismissal, user: user)

        user.destroy!

        dismissal.reload
        expect(dismissal.user_id).to be_nil
      end

      it 'nullifies approval_policy_merge_request_bypass_events when user is destroyed' do
        bypass_event = create(:approval_policy_merge_request_bypass_event, user: user)

        user.destroy!

        bypass_event.reload
        expect(bypass_event.user_id).to be_nil
      end
    end

    context 'with destroy dependency' do
      it 'destroys board_assignees when user is destroyed' do
        board =  create(:board, group: create(:group))

        assignee = BoardAssignee.create!(board: board, assignee: user)

        expect { user.destroy! }.to change { BoardAssignee.count }.by(-1)
        expect { assignee.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'nullifies ai_user_metrics when user is destroyed' do
        metrics = create(:ai_user_metrics, user: user)

        expect { user.destroy! }.to change { Ai::UserMetrics.count }.by(-1)
        expect { metrics.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'destroys targeted_message_dismissals when user is destroyed' do
        dismissal = create(:targeted_message_dismissal, user: user)

        expect { user.destroy! }.to change { Notifications::TargetedMessageDismissal.count }.by(-1)
        expect { dismissal.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
