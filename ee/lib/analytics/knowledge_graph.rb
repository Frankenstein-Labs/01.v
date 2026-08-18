# frozen_string_literal: true

module Analytics
  module KnowledgeGraph
    # Whether the Knowledge Graph (GKG) gRPC service is wired up on this
    # instance. Reads the instance-level `knowledge_graph.enabled` config
    # (gitlab.yml / Helm chart value `global.appConfig.knowledgeGraph.enabled`).
    def self.service_configured?
      !!Gitlab.config.knowledge_graph['enabled']
    rescue Gitlab::Configs::MissingConfig
      false
    end

    # Single source of truth for Orbit availability: the service must be
    # configured on this instance AND the rollout flag on for the user.
    def self.enabled_for?(user)
      service_configured? && ::Feature.enabled?(:knowledge_graph, user)
    end

    # Availability plus the licensing/tier check (delegated to OrbitLicense).
    def self.accessible_for?(user)
      enabled_for?(user) && OrbitLicense.available_for?(user)
    end
  end
end
