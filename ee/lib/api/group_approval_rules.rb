# frozen_string_literal: true

module API
  class GroupApprovalRules < ::API::Base
    include PaginationParams

    before { authenticate! }
    before { check_feature_availability }
    before { check_feature_flag }

    helpers ::API::Helpers::GroupApprovalRulesHelpers

    feature_category :security_policy_management

    params do
      requires :id, type: String, desc: 'The ID of a group'
    end
    resource :groups, requirements: ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      segment ':id/approval_rules' do
        desc 'List all approval rules for a group' do
          detail 'Lists all approval rules and any associated details for a specified group. ' \
            'Restricted to group administrators. ' \
            'Use the `page` and `per_page` pagination parameters to restrict the list of approval rules.'
          success ::API::Entities::GroupApprovalRule
          tags ['approval_rules']
        end
        params do
          use :pagination
        end
        route_setting :authorization, permissions: :read_approval_rule, boundary_type: :group
        get do
          authorize_group_approval_rule!

          group_approval_rules = paginate(user_group.approval_rules)

          present group_approval_rules, with: ::API::Entities::GroupApprovalRule
        end

        desc 'Create an approval rule for a group' do
          detail 'Creates an approval rule for a group. Restricted to group administrators. ' \
            'Do not use the `rule_type` field when building approval rules from the API. ' \
            'The field supports these rule types: - `any_approver`: A pre-configured default rule ' \
            'with `approvals_required` set to `0`.'
          success ::API::Entities::GroupApprovalRule
          tags ['approval_rules']
        end
        params do
          requires :name, type: String, desc: 'The name of the approval rule'
          requires :approvals_required, type: Integer, desc: 'The number of required approvals for this rule'
          use :group_approval_rule
        end
        route_setting :authorization, permissions: :create_approval_rule, boundary_type: :group
        post do
          create_group_approval_rule(present_with: ::API::Entities::GroupApprovalRule)
        end

        params do
          requires :approval_rule_id, type: Integer, desc: 'The ID of an approval rule'
        end

        params do
          optional :name, type: String, desc: 'The name of the approval rule'
          optional :approvals_required, type: Integer, desc: 'The number of required approvals for this rule'
          use :group_approval_rule
        end

        desc 'Update group approval rule' do
          success ::API::Entities::GroupApprovalRule
          tags ['approval_rules']
        end
        route_setting :authorization, permissions: :update_approval_rule, boundary_type: :group
        put ':approval_rule_id' do
          update_group_approval_rule(present_with: ::API::Entities::GroupApprovalRule)
        end
      end
    end
  end
end
