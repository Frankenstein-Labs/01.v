# frozen_string_literal: true

module EE
  module Onboarding
    module FeatureLibrary
      module FeatureMatchService
        extend ::Gitlab::Utils::Override
        include ::Gitlab::Utils::StrongMemoize
        include ::Gitlab::InternalEventsTracking

        SEARCH_RESOLUTION_EVENT = 'resolve_feature_discovery_search'

        override :execute
        def execute
          with_search_tracking { super }
        end

        override :ai_execute
        def ai_execute
          with_search_tracking { super }
        end

        override :ai_search_enabled?
        def ai_search_enabled?
          ::Feature.enabled?(:feature_discovery_gemini_search, user)
        end

        override :ai_search_available?
        def ai_search_available?
          return false unless ai_search_enabled?
          return false unless resource
          return false unless user

          resource.root_ancestor&.trial_active? || false
        end
        strong_memoize_attr :ai_search_available?

        private

        def with_search_tracking
          start = ::Gitlab::Metrics::System.monotonic_time
          result = yield
          duration_ms = ((::Gitlab::Metrics::System.monotonic_time - start) * 1000).round
          track_search_resolution(label: tracking_label, duration_ms: duration_ms)

          result
        end

        def track_search_resolution(label:, duration_ms:)
          return unless user
          return if label.blank? # matching never ran

          track_internal_event(
            SEARCH_RESOLUTION_EVENT,
            user: user,
            project: (resource if panel == 'project'),
            namespace: (resource if panel == 'group'),
            additional_properties: {
              label: label,
              value: duration_ms
            }
          )
        end

        override :ai_gateway_ids
        def ai_gateway_ids(normalized_query)
          return [] unless ai_search_available?

          catalog = ::Onboarding::FeatureLibrary::CatalogBuilder.new(
            panel: panel,
            user: user,
            resource: resource
          ).execute

          return [] if catalog.empty?

          result = completion(catalog, normalized_query).execute
          self.tracking_label = result.any? ? 'gemini' : 'no_gemini_match'
          result
        end

        def completion(catalog, query)
          ::Gitlab::Llm::AiGateway::Completions::FeatureDiscoverySearch.new(
            prompt_message,
            nil,
            action: :feature_discovery_search,
            query: query,
            catalog: catalog
          )
        end

        def prompt_message
          ::Gitlab::Llm::AiMessage.new(
            user: user,
            role: ::Gitlab::Llm::AiMessage::ROLE_USER,
            ai_action: :feature_discovery_search,
            context: ::Gitlab::Llm::AiMessageContext.new(resource: resource)
          )
        end
      end
    end
  end
end
