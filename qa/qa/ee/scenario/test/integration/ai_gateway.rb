# frozen_string_literal: true

module QA
  module EE
    module Scenario
      module Test
        module Integration
          class AiGateway < QA::Scenario::Test::Instance::All
            tags :ai_gateway

            pipeline_mappings test_on_omnibus: %w[ai-gateway]
          end
        end
      end
    end
  end
end
