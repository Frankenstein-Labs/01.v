# frozen_string_literal: true

module Ai
  module Catalog
    # Resolves the coding environment a Duo Agent Platform flow needs when its
    # workload starts.
    #
    # A flow declares the environment in one of two places:
    #
    #   - Catalog and custom flows: the `coding_environment` key of their
    #     `flow_config` definition, validated by `ai_catalog/flow_v2.json`.
    #   - Foundational flows: the `coding_environment` attribute of their
    #     `Ai::Catalog::FoundationalFlow` registry entry.
    #
    # The two sources are consulted in that order. An absent or unrecognized
    # declaration resolves to `:full`, so a typo can only ever widen the
    # environment, never silently remove a flow's repository access.
    class CodingEnvironment
      DEFAULT = :full

      VALUES = {
        'full' => :full,
        'none' => :none
      }.freeze

      class << self
        # @param workflow_definition [String, nil] the workflow's stable identity,
        #   e.g. "code_review/v1". Used to look up foundational flows.
        # @param flow_config [Hash, nil] the catalog/custom flow definition.
        # @return [Symbol] one of the values of {VALUES}, or {DEFAULT}.
        def resolve(workflow_definition:, flow_config: nil)
          VALUES.fetch(declared_value(workflow_definition, flow_config), DEFAULT)
        end

        private

        # Falls through on a missing value rather than on the absence of a
        # flow_config Hash, so a flow_config that declares nothing (or declares
        # it under a Symbol key) still reaches the foundational registry.
        def declared_value(workflow_definition, flow_config)
          from_flow_config(flow_config) || from_registry(workflow_definition)
        end

        def from_flow_config(flow_config)
          return unless flow_config.is_a?(Hash)

          flow_config['coding_environment'] || flow_config[:coding_environment]
        end

        def from_registry(workflow_definition)
          return if workflow_definition.blank?

          flow = FoundationalFlow.find_by_reference(workflow_definition) ||
            FoundationalFlow.find_by(display_name: workflow_definition)

          flow&.coding_environment
        end
      end
    end
  end
end
