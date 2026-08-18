# frozen_string_literal: true

module EE
  module Organizations
    module OrganizationHelper
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      override :organization_show_app_data
      def organization_show_app_data(organization)
        ::Gitlab::Json.safe_parse(super).merge(
          can_read_artifact_registry: can?(current_user, :read_artifact_registry, organization)
        ).to_json
      end

      override :organization_activity_app_data
      def organization_activity_app_data(organization)
        ::Gitlab::Json.safe_parse(super).merge(
          organization_activity_event_types: organization_activity_event_types
        ).to_json
      end

      private

      override :organization_activity_event_types
      def organization_activity_event_types
        super.concat([
          {
            title: _('Epic'),
            value: EventFilter::EPIC
          }
        ]).sort_by { |event| event[:value] }
      end
    end
  end
end
