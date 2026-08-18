# frozen_string_literal: true

module Mutations
  module Ai
    module SelfHostedModels
      class Create < Base
        graphql_name 'AiSelfHostedModelCreate'

        field_self_hosted_model

        arguments_for_model_attributes

        def resolve(**args)
          check_feature_access!

          result = ::Ai::SelfHostedModels::CreateService.new(current_user, args).execute

          if result.success?
            {
              self_hosted_model: result.payload,
              errors: [] # Errors are rescued below
            }
          else
            {
              self_hosted_model: nil,
              errors: [result.message]
            }
          end
        end
      end
    end
  end
end
