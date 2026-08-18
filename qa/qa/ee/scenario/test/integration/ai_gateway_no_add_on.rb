# frozen_string_literal: true

module QA
  module EE
    module Scenario
      module Test
        module Integration
          class AiGatewayNoAddOn < QA::Scenario::Test::Instance::All
            tags :ai_gateway_no_add_on

            pipeline_mappings test_on_omnibus: %w[ai-gateway-no-add-on]
          end
        end
      end
    end
  end
end
