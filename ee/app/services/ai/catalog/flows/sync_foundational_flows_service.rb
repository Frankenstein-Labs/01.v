# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class SyncFoundationalFlowsService
        include ::Gitlab::Utils::StrongMemoize
        include ::Gitlab::Loggable

        def initialize(container, current_user: nil)
          @container = container
          @current_user = current_user
        end

        def execute
          return remove_all_flows unless foundational_flows_enabled?

          sync_flows
        end

        private

        attr_reader :container, :current_user

        def foundational_flows_enabled?
          case container
          when Project
            container.project_setting&.duo_foundational_flows_enabled
          when Group, Namespace
            container.namespace_settings&.duo_foundational_flows_enabled
          else
            false
          end
        end

        def enabled_flow_catalog_item_ids
          container.enabled_flow_catalog_item_ids
        end

        def sync_flows
          target_ids = enabled_flow_catalog_item_ids
          items_by_id = Item.with_ids(target_ids).index_by(&:id)

          unless provision_ai_catalog_allowed?
            log_sync_failure
            remove_consumers_not_in(target_ids)
            return
          end

          target_ids.each do |catalog_item_id|
            item = items_by_id[catalog_item_id]
            unless item
              track_missing_item(catalog_item_id)
              log_sync_failure
              next
            end

            create_consumer_for_catalog_item(item)
          end

          remove_consumers_not_in(target_ids)
        end

        def create_consumer_for_catalog_item(item)
          parent_consumer = find_parent_consumer_if_needed(item)
          return log_sync_failure unless should_create_consumer?(parent_consumer)
          return log_sync_failure unless authorized_to_create_consumer?(item)

          result = create_or_find_consumer(item, parent_consumer)
          consumer = extract_consumer_from_result(result, item)

          log_sync_failure unless consumer

          create_trigger_if_needed(consumer, item) if consumer

          result
        end

        def find_parent_consumer_if_needed(item)
          return unless container.is_a?(Project)

          find_existing_consumer(item, container.root_ancestor)
        end

        def should_create_consumer?(parent_consumer)
          return true unless container.is_a?(Project)

          parent_consumer.present?
        end

        def authorized_to_create_consumer?(item)
          provision_ai_catalog_allowed? && Ability.allowed?(current_user, :read_ai_catalog_item, item)
        end

        def provision_ai_catalog_allowed?
          return false unless current_user

          Ability.allowed?(current_user, :provision_ai_catalog, container)
        end
        strong_memoize_attr :provision_ai_catalog_allowed?

        def create_or_find_consumer(item, parent_consumer)
          params = build_consumer_params(item, parent_consumer)

          ::Ai::Catalog::ItemConsumers::CreateService.new(
            container: container,
            current_user: current_user,
            params: params
          ).execute
        end

        def build_consumer_params(item, parent_consumer)
          params = { item: item }
          params[:parent_item_consumer] = parent_consumer if parent_consumer
          params
        end

        def extract_consumer_from_result(result, item)
          return result.payload[:item_consumer] if result.success?
          return find_existing_consumer(item, container) if item_already_configured?(result)

          nil
        end

        def item_already_configured?(result)
          result.error? && result.reason == :already_configured
        end

        def find_existing_consumer(item, target_container)
          existing_consumers_by_item_id(target_container)[item.id]
        end

        def existing_consumers_by_item_id(target_container)
          @existing_consumers_cache ||= {}
          cache_key = [target_container.class.name, target_container.id]
          @existing_consumers_cache[cache_key] ||= target_container
            .configured_ai_catalog_items
            .index_by(&:ai_catalog_item_id)
        end

        def create_trigger_if_needed(consumer, item)
          return unless container.is_a?(Project)

          create_trigger_for_consumer(consumer, item)
        end

        def create_trigger_for_consumer(consumer, item)
          trigger_params = build_trigger_params(consumer, item)
          return unless trigger_params.present?

          ::Ai::FlowTriggers::CreateService.new(
            project: container,
            current_user: current_user
          ).execute(trigger_params)
        end

        def build_trigger_params(consumer, item)
          return if consumer.active_service_account.nil?

          event_types = fetch_event_type_for_flow(item.foundational_flow_reference, consumer)
          return if event_types.empty?

          {
            description: "Foundational flow trigger for #{item.name}",
            ai_catalog_item_consumer_id: consumer.id,
            event_types: event_types
          }
        end

        def remove_consumers_not_in(catalog_item_ids)
          ids_to_remove = foundational_flow_ids - catalog_item_ids

          container.remove_foundational_flow_consumers(ids_to_remove)
        end

        def remove_all_flows
          container.remove_foundational_flow_consumers(foundational_flow_ids)
        end

        def foundational_flow_ids
          Item.foundational_flow_ids
        end

        def fetch_event_type_for_flow(foundational_flow_reference, consumer)
          flow_definition = ::Ai::Catalog::FoundationalFlow[foundational_flow_reference]
          return [] unless flow_definition.present? && flow_definition.triggers.present?

          flow_definition.triggers.reject { |event| trigger_exists?(consumer, event) }
        end

        def trigger_exists?(consumer, event)
          event_type = ::Ai::FlowTrigger::EVENT_TYPES.key(event)
          return true unless event_type

          container.ai_flow_triggers.triggered_on(event_type).by_item_consumer_ids([consumer.id]).exists?
        end

        def track_missing_item(catalog_item_id)
          ::Gitlab::ErrorTracking.track_exception(
            ActiveRecord::RecordNotFound.new("Couldn't find Ai::Catalog::Item with id=#{catalog_item_id}"),
            catalog_item_id: catalog_item_id,
            container_id: container.id
          )
        end

        def log_sync_failure
          payload = {
            Labkit::Fields::LOG_MESSAGE => 'Foundational flow was not synchronized',
            Labkit::Fields::GL_USER_ID => current_user&.id
          }
          container_id_field = container.is_a?(Project) ? Labkit::Fields::GL_PROJECT_ID : Labkit::Fields::GL_NAMESPACE_ID
          payload[container_id_field] = container.id

          Gitlab::AppLogger.warn(build_structured_payload_labkit(**payload.compact))
        end
      end
    end
  end
end
