# frozen_string_literal: true

module Graphql
  module Subscriptions
    module Security
      module PolicyScheduleTestRunUpdated
        module Helper
          def subscription_response
            subscription_channel = subscribe
            yield
            subscription_channel.mock_broadcasted_messages.first
          end

          def security_policy_schedule_test_run_updated_subscription(test_run, current_user)
            mock_channel = Graphql::Subscriptions::ActionCable::MockActionCable.get_mock_channel
            query = security_policy_schedule_test_run_updated_subscription_query(test_run)

            GitlabSchema.execute(query, context: { current_user: current_user, channel: mock_channel })

            mock_channel
          end

          private

          def security_policy_schedule_test_run_updated_subscription_query(test_run)
            <<~SUBSCRIPTION
              subscription {
                securityPolicyScheduleTestRunUpdated(testRunId: "#{test_run.to_global_id}") {
                  id
                  state
                  completed
                }
              }
            SUBSCRIPTION
          end
        end
      end
    end
  end
end
