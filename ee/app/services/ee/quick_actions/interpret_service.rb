# frozen_string_literal: true

module EE
  module QuickActions
    module InterpretService
      extend ActiveSupport::Concern
      # We use "prepended" here instead of including Gitlab::QuickActions::Dsl,
      # as doing so would clear any existing command definitions.
      prepended do
        # rubocop: disable Cop/InjectEnterpriseEditionModule
        include EE::Gitlab::QuickActions::EpicActions
        include EE::Gitlab::QuickActions::IssueActions
        include EE::Gitlab::QuickActions::IssueAndMergeRequestActions
        include EE::Gitlab::QuickActions::MergeRequestActions
        include EE::Gitlab::QuickActions::RelateActions
        include EE::Gitlab::QuickActions::WorkItemActions
        include EE::Gitlab::QuickActions::AmazonQActions
        # rubocop: enable Cop/InjectEnterpriseEditionModule
      end

      # Quick actions that are safe for AI workflows because they
      # only set attributes that Duo can already set via dedicated API parameters.
      # Actions that dangerously change state or trigger side effects (e.g. /merge, /close,
      # /approve) are intentionally excluded and remain blocked.
      ALLOWED_AI_QUICK_ACTIONS = %i[
        label unlabel relabel
        milestone remove_milestone
        assign unassign reassign
        request_review unassign_reviewer reassign_reviewer
        title
        due remove_due_date
        estimate remove_estimate
        spend remove_time_spent
        weight clear_weight
        health_status clear_health_status
        iteration remove_iteration
        status
        draft ready
      ].freeze

      def execute(content, quick_action_target, only: nil)
        result = super

        check_quick_actions_availability(result.last)
        result
      end

      private

      def check_quick_actions_availability(commands)
        return if quick_actions_check_not_needed?(commands)
        return if params[:scope_validator].permit_quick_actions?

        blocked = blocked_ai_quick_actions(commands)
        return if blocked.empty?

        message = "Quick actions #{blocked.join(', ')} cannot be used with AI workflows."
        raise ::QuickActions::InterpretService::QuickActionsNotAllowedError, message
      end

      def blocked_ai_quick_actions(commands)
        commands.reject do |name|
          definition = self.class.definition_by_name(name)
          definition && ALLOWED_AI_QUICK_ACTIONS.include?(definition.name)
        end
      end

      def quick_actions_check_not_needed?(commands)
        commands.blank? || params[:scope_validator].blank?
      end
    end
  end
end
