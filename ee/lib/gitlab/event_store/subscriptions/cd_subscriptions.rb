# frozen_string_literal: true

module Gitlab
  module EventStore
    module Subscriptions
      class CdSubscriptions < BaseSubscriptions
        def register
          store.subscribe ::Cd::ArtifactSources::PublishFromRegistryWorker,
            to: ::ContainerRegistry::ImagePushedEvent,
            if: ->(event) { ::Cd::ArtifactSources::PublishFromRegistryWorker.dispatch?(event) }

          store.subscribe ::Cd::Versions::CreateFromArtifactWorker,
            to: ::Cd::ArtifactPublishedEvent
        end
      end
    end
  end
end
