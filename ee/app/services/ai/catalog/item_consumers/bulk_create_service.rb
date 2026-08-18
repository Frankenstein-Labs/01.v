# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      class BulkCreateService
        include Gitlab::Utils::StrongMemoize
        include ::Ai::Catalog::Loggable

        def initialize(current_user:, item:, projects:, trigger_types: nil, trigger_filter: nil, pinned_version: nil)
          @current_user = current_user
          @item = item
          @projects = projects
          @trigger_types = trigger_types
          @trigger_filter = trigger_filter
          @pinned_version = pinned_version
        end

        def execute
          failures = []

          projects.each do |project|
            response = ::Ai::Catalog::ItemConsumers::CreateService.new(
              container: project,
              current_user: current_user,
              params: create_service_params
            ).execute

            if !response.success? && response.reason != :already_configured
              failures << { project_id: project.id, error_message: Array(response.message).join(', ') }
            end
          rescue StandardError => e
            Gitlab::ErrorTracking.track_exception(e, project_id: project.id, item_id: item.id)
            failures << {
              project_id: project.id,
              error_message: s_('AICatalog|Something went wrong on our end whilst processing this project')
            }
          end

          log_failures(failures)

          ServiceResponse.success(payload: { successful_count: projects.size - failures.count, failures: failures })
        end

        private

        attr_reader :current_user, :item, :projects, :trigger_types, :trigger_filter, :pinned_version

        def log_failures(failures)
          ai_catalog_logger.context(item:)

          failures.each do |failure|
            ai_catalog_logger.error(
              message: 'Failed to create item consumer for project',
              project_id: failure[:project_id],
              error_message: failure[:error_message]
            )
          end
        end

        strong_memoize_attr def create_service_params
          { item:, trigger_types:, trigger_filter:, pinned_version: }.compact
        end
      end
    end
  end
end
