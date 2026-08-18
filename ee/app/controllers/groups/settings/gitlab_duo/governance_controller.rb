# frozen_string_literal: true

module Groups
  module Settings
    module GitlabDuo
      class GovernanceController < Groups::ApplicationController
        feature_category :compliance_management

        before_action do
          push_frontend_feature_flag(:gitlab_duo_governance_settings, @group, type: :beta)
          push_frontend_feature_flag(:agent_artifacts_page, @group, type: :beta)
          push_frontend_feature_flag(:ai_governance_dashboard, @group, type: :wip)
        end

        def index
          return render_404 unless render_governance_page?

          @ai_audit_events_storage_enabled = group.ai_audit_events_storage_enabled
        end

        private

        def render_governance_page?
          # Top-level groups only: the tool-rules GraphQL surface
          # (Resolvers::Ai::ToolRulesResolver and the update mutations)
          # resolves root namespaces exclusively, so a subgroup page would
          # render and then fail every query.
          group.root? &&
            group.licensed_ai_features_available? &&
            Feature.enabled?(:gitlab_duo_governance_settings, group) &&
            can?(current_user, :read_ai_tool_rule, group)
        end
      end
    end
  end
end
