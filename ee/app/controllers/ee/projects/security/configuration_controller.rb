# frozen_string_literal: true

module EE
  module Projects
    module Security
      module ConfigurationController
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          alias_method :vulnerable, :project

          before_action :ensure_security_dashboard_feature_enabled!, except: [:show]
          before_action :authorize_read_security_dashboard!, except: [:show]

          before_action only: [:show] do
            push_force_frontend_feature_flag(:vulnerability_archival, project.vulnerability_archival_enabled?)
            push_force_frontend_feature_flag(:vulnerabilities_across_contexts, ::Security::VAC.enabled?(project))
            push_licensed_feature(:security_attributes, project&.root_ancestor)
            push_licensed_feature(:security_scan_profiles, project&.root_ancestor)
            push_frontend_feature_flag(:security_scan_profiles_feature, project&.root_ancestor)
            push_frontend_feature_flag(:security_scan_profiles_status_indicators, project.root_ancestor)
          end

          feature_category :security_testing_configuration, [:show]

          urgency :low, [:show]
        end

        private

        def security_dashboard_feature_enabled?
          vulnerable.feature_available?(:security_dashboard)
        end

        def can_read_security_dashboard?
          can?(current_user, :read_project_security_dashboard, vulnerable)
        end

        def ensure_security_dashboard_feature_enabled!
          render_404 unless security_dashboard_feature_enabled?
        end

        def authorize_read_security_dashboard!
          render_403 unless can_read_security_dashboard?
        end
      end
    end
  end
end
