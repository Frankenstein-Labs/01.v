# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      class BulkCreateWorker
        include ApplicationWorker

        feature_category :workflow_catalog
        data_consistency :sticky
        urgency :low
        idempotent!

        defer_on_database_health_signal :gitlab_main, [:ai_catalog_item_consumers, :projects], 1.minute

        def perform(current_user_id, item_id, project_ids, params = {})
          trigger_types = params['trigger_types']
          trigger_filter = params['trigger_filter']
          pinned_version = params['pinned_version']

          current_user = User.find_by_id(current_user_id)
          return unless current_user

          return unless Feature.enabled?(:ai_catalog_bulk_item_consumer_create, current_user)

          item = ::Ai::Catalog::Item.not_deleted.find_by_id(item_id)
          return unless item

          projects = Project.id_in(project_ids)
          return if projects.empty?

          response = ::Ai::Catalog::ItemConsumers::BulkCreateService.new(
            current_user:, item:, projects:, trigger_types:, trigger_filter:, pinned_version:
          ).execute

          ::Ai::Catalog::BulkItemConsumerMailer.bulk_create_result_email(
            user: current_user,
            item: item,
            successful_count: response.payload[:successful_count],
            failures: response.payload[:failures]
          ).deliver_later
        end
      end
    end
  end
end
