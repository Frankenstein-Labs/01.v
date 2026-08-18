# frozen_string_literal: true

module API
  module Entities
    class ApprovalState < Grape::Entity
      expose :merge_request, merge: true, using: ::API::Entities::IssuableEntity

      expose :merge_status, documentation: { type: 'String', example: 'can_be_merged' } do |approval_state|
        approval_state.merge_request.public_merge_status
      end

      expose :approved?, as: :approved, documentation: { type: 'Boolean' }

      expose :approvals_required, documentation: { type: 'Integer', example: 2 }

      expose :approvals_left, documentation: { type: 'Integer', example: 2 }

      expose :require_password_to_approve, documentation: { type: 'Boolean' } do |approval_state|
        approval_state.project.require_password_to_approve?
      end

      expose :approved_by, using: ::API::Entities::Approvals, documentation: { is_array: true } do |approval_state|
        approval_state.merge_request.approvals
      end

      expose :suggested_approvers,
        using: ::API::Entities::UserBasic, documentation: { is_array: true } do |approval_state, options|
          approval_state.suggested_approvers(current_user: options[:current_user])
        end

      # @deprecated, reads from first regular rule instead
      expose :approvers, documentation: { type: 'Hash', is_array: true } do |approval_state|
        # rubocop:disable Lint/AssignmentInCondition -- TODO: needs to be fixed
        if rule = approval_state.first_regular_rule
          rule.users.map do |user|
            { user: ::API::Entities::UserBasic.represent(user) }
          end
        else
          []
        end
        # rubocop:enable Lint/AssignmentInCondition
      end
      # @deprecated, reads from first regular rule instead
      expose :approver_groups, documentation: { type: 'Hash', is_array: true } do |approval_state|
        # rubocop:disable Lint/AssignmentInCondition -- TODO: needs to be fixed
        if rule = approval_state.first_regular_rule
          presenter = ::ApprovalRulePresenter.new(rule, current_user: options[:current_user])
          presenter.groups.map do |group|
            { group: ::API::Entities::Group.represent(group) }
          end
        else
          []
        end
        # rubocop:enable Lint/AssignmentInCondition
      end

      expose :user_has_approved, documentation: { type: 'Boolean' } do |approval_state, options|
        approval_state.merge_request.approved_by?(options[:current_user])
      end

      expose :user_can_approve, documentation: { type: 'Boolean' } do |approval_state, options|
        approval_state.eligible_for_approval_by?(options[:current_user])
      end

      expose :approval_rules_left, using: ::API::Entities::ApprovalRuleShort, documentation: { is_array: true }

      expose :has_approval_rules, documentation: { type: 'Boolean' } do |approval_state|
        approval_state.user_defined_rules.present?
      end

      expose :merge_request_approvers_available, documentation: { type: 'Boolean' } do |approval_state|
        # rubocop:disable Gitlab/FeatureAvailableUsage -- TODO: needs to be fixed
        approval_state.project.feature_available?(:merge_request_approvers)
        # rubocop:enable Gitlab/FeatureAvailableUsage
      end

      expose :multiple_approval_rules_available, documentation: { type: 'Boolean' } do |approval_state|
        approval_state.project.multiple_approval_rules_available?
      end

      expose :invalid_approvers_rules, using: ::API::Entities::ApprovalRuleShort, documentation: { is_array: true }
    end
  end
end
