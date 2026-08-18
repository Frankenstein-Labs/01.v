# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class SettingsBasedUpdateService < BaseUpdateService
      private

      def supported?
        TYPE_MAPPINGS[analyzer_type].present?
      end

      def build_projects_relation
        super.with_security_setting
      end

      def analyzers_statuses
        @analyzers_statuses ||= projects.each_with_object({}) do |project, memo|
          setting_field = TYPE_MAPPINGS[@analyzer_type][:setting_field]
          setting_enabled = project.security_setting&.read_attribute(setting_field) ||
            has_applicable_profile?(project) ||
            instance_level_enforced?
          setting_status = status_to_symbol(setting_enabled)
          setting_type = TYPE_MAPPINGS[@analyzer_type][:setting_type]

          aggregated_status =
            build_aggregated_type_status(project, TYPE_MAPPINGS[@analyzer_type][:setting_type],
              { status: setting_status })

          memo[project] = {
            setting_type => build_analyzer_status_hash(project, setting_type, setting_status)
          }.tap do |hash|
            hash[aggregated_status[:analyzer_type]] = aggregated_status if aggregated_status
          end
        end
      end

      def status_to_symbol(status)
        status ? :success : :not_configured
      end

      def instance_level_enforced?
        return false unless @analyzer_type == :secret_detection

        return @instance_level_enforced if defined?(@instance_level_enforced)

        @instance_level_enforced =
          ::Gitlab::CurrentSettings.current_application_settings.secret_push_protection_enforced
      end
    end
  end
end
