# frozen_string_literal: true

module Projects
  module Settings
    module GitlabDuo
      class GovernanceController < Projects::ApplicationController
        layout 'project_settings'
        feature_category :compliance_management

        before_action :authorize_read_governance!
        before_action do
          push_frontend_feature_flag(:gitlab_duo_governance_settings, project.root_ancestor, type: :beta)
          push_frontend_feature_flag(:agent_artifacts_page, project.root_ancestor, type: :beta)
          push_frontend_feature_flag(:ai_governance_dashboard, project.root_ancestor, type: :wip)
        end

        def index
          @ai_tool_rules_editable = can?(current_user, :update_ai_tool_rule, project.root_ancestor)
          @ai_audit_events_storage_enabled = project.ai_audit_events_storage_enabled
        end

        private

        def authorize_read_governance!
          render_404 unless render_governance_page?
        end

        def render_governance_page?
          project.root_ancestor.is_a?(Group) &&
            project.licensed_ai_features_available? &&
            Feature.enabled?(:gitlab_duo_governance_settings, project.root_ancestor) &&
            can?(current_user, :read_ai_tool_rule, project.root_ancestor)
        end
      end
    end
  end
end
