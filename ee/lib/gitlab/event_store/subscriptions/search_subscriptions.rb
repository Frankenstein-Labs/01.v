# frozen_string_literal: true

module Gitlab
  module EventStore
    module Subscriptions
      class SearchSubscriptions < BaseSubscriptions # rubocop:disable Search/NamespacedClass -- Following EventStore pattern
        def register
          register_zoekt_events
          register_elastic_events
          register_finder_cache_events
        end

        private

        def register_finder_cache_events
          search_infra_enabled = ->(_) do
            ::Gitlab::CurrentSettings.elasticsearch_indexing? ||
              ::Gitlab::CurrentSettings.zoekt_indexing_enabled? ||
              knowledge_graph_infra_enabled?
          end

          [
            ::ProjectAuthorizations::AuthorizationsAddedEvent,
            ::ProjectAuthorizations::AuthorizationsRemovedEvent,
            ::Members::MembersAddedEvent,
            ::Members::DestroyedEvent,
            ::Members::UpdatedEvent,
            ::Members::AcceptedInviteEvent,
            ::Members::MembershipModifiedByAdminEvent
          ].each do |event_class|
            store.subscribe ::Search::ExpireFinderCacheWorker, to: event_class, if: search_infra_enabled
          end
        end

        # Backend event-store subscriptions: gated on the infra flag OR the config directly.
        def knowledge_graph_infra_enabled?
          ::Feature.enabled?(:knowledge_graph_infra, :instance) ||
            ::Gitlab.config.knowledge_graph['enabled']
        end

        def register_zoekt_events
          zoekt_enabled = ->(_) { ::Search::Zoekt.licensed_and_indexing_enabled? }

          # Subscriptions gated by `zoekt_enabled`:
          # - React to generic events (e.g. ProjectDeletedEvent) that fire on every instance
          #   regardless of Zoekt usage. The guard prevents pointless job enqueueing on
          #   instances where Zoekt is not licensed or indexing is disabled.
          # - Or schedule new indexing work / perform Zoekt-affecting computations
          #   (initial indexing, repo (re)indexing, storage/watermark recalculation,
          #   SaaS rollout). The guard avoids bootstrapping or mutating state during a
          #   disabled window.

          store.subscribe ::Search::Zoekt::DefaultBranchChangedWorker,
            to: ::Repositories::DefaultBranchChangedEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::DeleteProjectEventWorker,
            to: ::Projects::ProjectDeletedEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::ProjectVisibilityChangedEventWorker,
            to: ::Projects::ProjectVisibilityChangedEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::ProjectMarkedAsArchivedEventWorker,
            to: ::Projects::ProjectArchivedEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::GroupArchivedEventWorker,
            to: ::Namespaces::Groups::GroupArchivedEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::ProjectFeaturesChangedEventWorker,
            to: ::Projects::ProjectFeaturesChangedEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::ProjectPathChangedEventWorker,
            to: ::Projects::ProjectPathChangedEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::GroupPathChangedEventWorker,
            to: ::Namespaces::Groups::GroupPathChangedEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::ForceUpdateOverprovisionedIndexEventWorker,
            to: ::Search::Zoekt::ForceUpdateOverprovisionedIndexEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::InitialIndexingEventWorker,
            to: ::Search::Zoekt::InitialIndexingEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::RepoToIndexEventWorker,
            to: ::Search::Zoekt::RepoToIndexEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::RepoToReindexEventWorker,
            to: ::Search::Zoekt::RepoToReindexEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::NodeWithNegativeUnclaimedStorageEventWorker,
            to: ::Search::Zoekt::NodeWithNegativeUnclaimedStorageEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::UpdateIndexUsedStorageBytesEventWorker,
            to: ::Search::Zoekt::UpdateIndexUsedStorageBytesEvent,
            if: zoekt_enabled

          store.subscribe ::Search::Zoekt::SaasRolloutEventWorker,
            to: ::Search::Zoekt::SaasRolloutEvent,
            if: zoekt_enabled

          # Subscriptions without a guard:
          # These workers react to Zoekt-internal events published by SchedulingService
          # (already gated upstream by `licensed_and_indexing_enabled?`) or by task
          # processing callbacks (which only run when Zoekt is active). The work is
          # pure DB bookkeeping on Zoekt's own tables - recording state transitions
          # the SQL scopes have already determined. Running them during a brief
          # disabled-mid-flight window leaves rows in a consistent state rather than
          # stranded, so the guard would add no protection.

          store.subscribe ::Search::Zoekt::TaskFailedEventWorker,
            to: ::Search::Zoekt::TaskFailedEvent

          store.subscribe ::Search::Zoekt::IndexMarkAsPendingEvictionEventWorker,
            to: ::Search::Zoekt::IndexMarkPendingEvictionEvent

          store.subscribe ::Search::Zoekt::OrphanedIndexEventWorker,
            to: ::Search::Zoekt::OrphanedIndexEvent

          store.subscribe ::Search::Zoekt::IndexMarkedAsToDeleteEventWorker,
            to: ::Search::Zoekt::IndexMarkedAsToDeleteEvent

          store.subscribe ::Search::Zoekt::OrphanedRepoEventWorker,
            to: ::Search::Zoekt::OrphanedRepoEvent

          store.subscribe ::Search::Zoekt::RepoMarkedAsToDeleteEventWorker,
            to: ::Search::Zoekt::RepoMarkedAsToDeleteEvent

          store.subscribe ::Search::Zoekt::LostNodeEventWorker,
            to: ::Search::Zoekt::LostNodeEvent

          store.subscribe ::Search::Zoekt::IndexToEvictEventWorker,
            to: ::Search::Zoekt::IndexToEvictEvent

          store.subscribe ::Search::Zoekt::IndexMarkedAsReadyEventWorker,
            to: ::Search::Zoekt::IndexMarkedAsReadyEvent

          store.subscribe ::Search::Zoekt::TooManyReplicasEventWorker,
            to: ::Search::Zoekt::TooManyReplicasEvent
        end

        def register_elastic_events
          store.subscribe ::Search::ElasticDefaultBranchChangedWorker, to: ::Repositories::DefaultBranchChangedEvent,
            if: ->(_) { ::Gitlab::CurrentSettings.elasticsearch_indexing? }
          store.subscribe ::Search::Elastic::GroupArchivedEventWorker, to: ::Namespaces::Groups::GroupArchivedEvent,
            if: ->(_) { ::Gitlab::CurrentSettings.elasticsearch_indexing? }
          store.subscribe ::Search::Elastic::ProjectArchivedEventWorker, to: ::Projects::ProjectArchivedEvent,
            if: ->(_) { ::Gitlab::CurrentSettings.elasticsearch_indexing? }
        end
      end
    end
  end
end
