# frozen_string_literal: true

module Graphql
  module Subscriptions
    module Cd
      module RolloutStepUpdated
        module Helper
          def subscription_response
            subscription_channel = subscribe
            yield
            subscription_channel.mock_broadcasted_messages.first
          end

          def cd_rollout_step_updated_subscription(rollout, current_user)
            mock_channel = Graphql::Subscriptions::ActionCable::MockActionCable.get_mock_channel
            query = cd_rollout_step_updated_subscription_query(rollout)

            GitlabSchema.execute(query, context: { current_user: current_user, channel: mock_channel })

            mock_channel
          end

          private

          def cd_rollout_step_updated_subscription_query(rollout)
            <<~SUBSCRIPTION
              subscription {
                cdRolloutStepUpdated(rolloutId: "#{rollout.to_global_id}") {
                  id
                  state
                  error
                  stepType
                  path
                }
              }
            SUBSCRIPTION
          end
        end
      end
    end
  end
end
