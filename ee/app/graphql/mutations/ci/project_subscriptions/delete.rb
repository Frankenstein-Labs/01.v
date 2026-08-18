# frozen_string_literal: true

module Mutations
  module Ci
    module ProjectSubscriptions
      class Delete < BaseMutation
        graphql_name 'ProjectSubscriptionDelete'

        authorize :delete_project_subscription

        argument :subscription_id, Types::GlobalIDType[::Ci::Subscriptions::Project],
          required: true,
          description: 'ID of the subscription to delete.'

        field :project,
          Types::ProjectType,
          null: true,
          description: "Project after mutation."

        attr_reader :subscription

        def resolve(subscription_id:)
          @subscription = authorized_find!(id: subscription_id)

          response = ::Ci::DeleteProjectSubscriptionService
                       .new(subscription: subscription, user: current_user).execute

          if response.error?
            result(errors: response.errors)
          else
            result(project: response.payload)
          end
        end

        private

        def result(project: nil, errors: [])
          {
            project: project,
            errors: errors
          }
        end
      end
    end
  end
end
