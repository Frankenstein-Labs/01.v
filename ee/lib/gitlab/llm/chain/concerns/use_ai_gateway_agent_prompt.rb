# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Concerns
        module UseAiGatewayAgentPrompt
          def use_ai_gateway_agent_prompt?
            Feature.enabled?(:"prompt_migration_#{unit_primitive_value}", context.current_user)
          end

          def unit_primitive
            return super unless use_ai_gateway_agent_prompt?

            unit_primitive_value
          end

          private

          # This module is included into executors of the following format:
          #
          # Gitlab::Llm::Chain::Tools::ExplainCode::Executor
          #
          # In order to get unit_primitive from it, we take ExplainCode module by index
          def unit_primitive_value
            self.class.name.split('::')[-2].underscore
          end
        end
      end
    end
  end
end
