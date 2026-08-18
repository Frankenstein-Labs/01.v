# frozen_string_literal: true

module API
  module Helpers
    module GroupApprovalRulesHelpers
      extend Grape::API::Helpers

      params :group_approval_rule do
        optional :rule_type, type: String, desc: 'The type of approval rule', documentation: { example: 'regular' }
        optional :user_ids, type: Array[Integer],
          coerce_with: ::API::Validations::Types::CommaSeparatedToIntegerArray.coerce,
          desc: 'The user ids for this rule'
        optional :group_ids, type: Array[Integer],
          coerce_with: ::API::Validations::Types::CommaSeparatedToIntegerArray.coerce,
          desc: 'The group ids for this rule'
      end

      def check_feature_availability
        forbidden! unless ::License.feature_available?(:merge_request_approvers)
      end

      def check_feature_flag
        not_found! unless ::Feature.enabled?(:approval_group_rules, user_group)
      end

      def authorize_group_approval_rule!
        return if can?(current_user, :admin_group, user_group)

        authorize! :admin_merge_request_approval_settings, user_group
      end

      def create_group_approval_rule(present_with:)
        authorize_group_approval_rule!

        create_params = declared_params(include_missing: false)
        result = ::ApprovalRules::CreateService.new(user_group, current_user, create_params).execute

        if result[:status] == :success
          present result[:rule], with: present_with, current_user: current_user
        else
          render_api_error!(result.message, result.cause.access_denied? ? 403 : 400)
        end
      end

      def update_group_approval_rule(present_with:)
        authorize_group_approval_rule!

        approval_rule = user_group.approval_rules.find_by_id(params[:approval_rule_id])
        not_found!('Approval Rule') unless approval_rule

        update_params = declared_params(include_missing: false)
        result = ::ApprovalRules::UpdateService.new(approval_rule, current_user, update_params).execute

        if result[:status] == :success
          present result[:rule], with: present_with, current_user: current_user
        else
          render_api_error!(result.message, result.cause.access_denied? ? 403 : 400)
        end
      end
    end
  end
end
