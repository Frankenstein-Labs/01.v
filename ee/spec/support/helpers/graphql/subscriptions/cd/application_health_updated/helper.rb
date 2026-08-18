# frozen_string_literal: true

module Graphql
  module Subscriptions
    module Cd
      module ApplicationHealthUpdated
        module Helper
          def subscription_response
            subscription_channel = subscribe
            yield
            subscription_channel.mock_broadcasted_messages.first
          end

          def cd_application_health_updated_subscription(organization, current_user)
            mock_channel = Graphql::Subscriptions::ActionCable::MockActionCable.get_mock_channel
            query = cd_application_health_updated_subscription_query(organization)

            GitlabSchema.execute(query, context: { current_user: current_user, channel: mock_channel })

            mock_channel
          end

          private

          def cd_application_health_updated_subscription_query(organization)
            <<~SUBSCRIPTION
              subscription {
                cdApplicationHealthUpdated(organizationId: "#{organization.to_global_id}") {
                  id
                  name
                  health
                }
              }
            SUBSCRIPTION
          end
        end
      end
    end
  end
end
