# frozen_string_literal: true

module QA
  module EE
    module Scenario
      module Test
        module Integration
          # Selects the Duo Agent Platform foundational-flow smoke spec into its own omnibus
          # e2e job (duo-agent-platform), separate from ai-gateway. The gem-side
          # Test::Integration::DuoAgentPlatform scenario boots the agentic-mock Duo Workflow
          # Service alongside the mock AI Gateway; the spec provisions the Duo entitlement
          # over the REST API.
          class DuoAgentPlatform < QA::Scenario::Test::Instance::All
            tags :duo_agent_platform

            pipeline_mappings test_on_omnibus: %w[duo-agent-platform]
          end
        end
      end
    end
  end
end
