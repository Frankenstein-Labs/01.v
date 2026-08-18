# frozen_string_literal: true

module ArtifactRegistry
  module CachesClient
    extend ActiveSupport::Concern
    include Gitlab::Utils::StrongMemoize

    def artifact_registry_client(current_user:)
      strong_memoize_with(:artifact_registry_client, current_user) do
        ::ArtifactRegistry::Client.new(current_user: current_user)
      end
    end
  end
end
