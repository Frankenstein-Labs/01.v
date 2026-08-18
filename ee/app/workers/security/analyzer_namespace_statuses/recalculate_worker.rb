# frozen_string_literal: true

module Security
  module AnalyzerNamespaceStatuses
    class RecalculateWorker
      include ApplicationWorker

      idempotent!
      data_consistency :sticky
      deduplicate :until_executing, including_scheduled: true
      feature_category :security_asset_inventories
      defer_on_database_health_signal :gitlab_sec, [:analyzer_namespace_statuses], 30.seconds

      def perform(group_id)
        group = Group.find_by_id(group_id)
        return unless group.present?

        AnalyzerNamespaceStatuses::RecalculateService.execute(group)
      end
    end
  end
end
