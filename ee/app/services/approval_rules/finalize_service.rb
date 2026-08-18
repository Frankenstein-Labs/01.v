# frozen_string_literal: true

module ApprovalRules
  class FinalizeService
    attr_reader :merge_request

    def initialize(merge_request)
      @merge_request = merge_request
    end

    def execute
      return unless merge_request.merged?

      merge_request.finalize_rules do
        ApplicationRecord.transaction do
          handling_of_rules

          merge_request.approval_rules.each(&:sync_approved_approvers)
        end
      end
    end

    private

    def handling_of_rules
      if merge_request.approval_state.approval_rules_overwritten?
        merge_group_members_into_users
      else
        copy_project_rules
      end

      update_code_owner_rules
    end

    def update_code_owner_rules
      wrapped_rules = merge_request.approval_rules.code_owner.map do |rule|
        ApprovalWrappedRule.wrap(merge_request, rule)
      end

      wrapped_rules.each(&:finalize!)
    end

    def merge_group_members_into_users
      merge_request.approval_rules.each do |rule|
        rule.users |= rule.group_users
        applicable_post_merge = rule.applicable_to_branch?(merge_request.target_branch)

        rule.update!(applicable_post_merge: applicable_post_merge)
      end
    end

    def copy_project_rules
      attributes_to_slice = %w[approvals_required name report_type rule_type]

      # All User Defined MR rules are not applicable as we used project rules during merge
      # All other rules need to take into consideration if they are applicable or not
      applicable_ids = merge_request.approval_rules.not_regular_or_any_approver
        .applicable_to_branch(merge_request.target_branch)
        .map(&:id)

      merge_request.approval_rules.set_applicable_when_copying_rules(applicable_ids)

      merge_request.target_project.regular_or_any_approver_approval_rules.each do |project_rule|
        users = project_rule.approvers
        groups = project_rule.groups.public_or_visible_to_user(merge_request.author)
        applicable_post_merge = project_rule.applies_to_branch?(merge_request.target_branch)

        new_rule = merge_request.approval_rules.build(
          project_rule.attributes.slice(*attributes_to_slice)
          .merge(users: users, groups: groups,
            applicable_post_merge: applicable_post_merge)
        )

        if new_rule.valid?
          new_rule.save!
        else
          merge_request.approval_rules.delete(new_rule)

          Gitlab::AppLogger.debug(
            "Failed to persist approval rule: #{new_rule.errors.full_messages}."
          )
        end
      end
    end
  end
end
