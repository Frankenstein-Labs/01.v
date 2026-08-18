# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      class AmazonQ < CodeSuggestions::Prompts::Base
        GATEWAY_PROMPT_VERSION = 2
        MODEL_PROVIDER = 'amazon_q'

        def request_params
          {
            prompt_version: GATEWAY_PROMPT_VERSION,
            model_provider: self.class::MODEL_PROVIDER,
            model_name: self.class::MODEL_PROVIDER,
            # rubocop:disable Gitlab/AvoidUserOrganization -- user-scoped lookup; in Cells 1.0 a user belongs to exactly one organization
            role_arn: ::Ai::Setting.for_organization_read_only(current_user.organization).amazon_q_role_arn
            # rubocop:enable Gitlab/AvoidUserOrganization
          }
        end
      end
    end
  end
end
