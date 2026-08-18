# frozen_string_literal: true

module Graphql
  module Subscriptions
    module Cd
      module RolloutUpdated
        module Helper
          def subscription_response
            subscription_channel = subscribe
            yield
            subscription_channel.mock_broadcasted_messages.first
          end

          def cd_rollout_updated_subscription(application, current_user)
            mock_channel = Graphql::Subscriptions::ActionCable::MockActionCable.get_mock_channel
            query = cd_rollout_updated_subscription_query(application)

            GitlabSchema.execute(query, context: { current_user: current_user, channel: mock_channel })

            mock_channel
          end

          private

          def cd_rollout_updated_subscription_query(application)
            <<~SUBSCRIPTION
              subscription {
                cdRolloutUpdated(applicationId: "#{application.to_global_id}") {
                  reason
                  rollout {
                    id
                  }
                  rolloutEnvironment {
                    id
                  }
                  thread {
                    id
                  }
                }
              }
            SUBSCRIPTION
          end
        end
      end
    end
  end
end
