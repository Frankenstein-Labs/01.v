# frozen_string_literal: true

module QA
  module EE
    module Scenario
      module Test
        module Integration
          class AiGatewayNoSeatAssigned < QA::Scenario::Test::Instance::All
            tags :ai_gateway_no_seat_assigned

            pipeline_mappings test_on_omnibus: %w[ai-gateway-no-seat-assigned]
          end
        end
      end
    end
  end
end
