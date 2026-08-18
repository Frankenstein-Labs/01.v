# frozen_string_literal: true

module Graphql
  module Subscriptions
    module Security
      module PolicyProjectCreated
        module Helper
          def subscription_response
            subscription_channel = subscribe
            yield
            subscription_channel.mock_broadcasted_messages.first
          end

          def security_policy_project_created_subscription(container, current_user)
            mock_channel = Graphql::Subscriptions::ActionCable::MockActionCable.get_mock_channel
            query = security_policy_project_created_subscription_query(container)

            GitlabSchema.execute(query, context: { current_user: current_user, channel: mock_channel })

            mock_channel
          end

          private

          def security_policy_project_created_subscription_query(container)
            <<~SUBSCRIPTION
              subscription {
                securityPolicyProjectCreated(fullPath: \"#{container.full_path}\") {
                  project {
                    name
                  }
                  status
                  errors
                  errorMessage
                }
              }
            SUBSCRIPTION
          end
        end
      end
    end
  end
end
