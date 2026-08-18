# frozen_string_literal: true

module ArtifactRegistry
  # Shared feature-flag gate and client acquisition for the Artifact Registry
  # GraphQL surface. The resolver reads the loaded organization from `object`;
  # the mutation reads it from `context[:current_organization]`. Both include
  # this concern and expose the organization through #artifact_registry_organization.
  module AcquiresClient
    extend ActiveSupport::Concern

    private

    def artifact_registry_enabled?
      ::Feature.enabled?(:artifact_registry_ui, artifact_registry_organization)
    end

    def artifact_registry_client
      artifact_registry_organization.artifact_registry_client(current_user: current_user)
    end

    def artifact_registry_slug
      artifact_registry_organization.artifact_registry_slug
    end

    def artifact_registry_organization
      raise NotImplementedError, "#{self.class} must implement #artifact_registry_organization"
    end
  end
end
