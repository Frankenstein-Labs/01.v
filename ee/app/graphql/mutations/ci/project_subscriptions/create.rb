# frozen_string_literal: true

module Mutations
  module Ci
    module ProjectSubscriptions
      class Create < BaseMutation
        graphql_name 'ProjectSubscriptionCreate'

        include FindsProject

        authorize :create_pipeline_subscription

        argument :project_path, GraphQL::Types::String,
          required: true,
          description: 'Full path of the downstream project of the Project Subscription.'

        argument :upstream_path, GraphQL::Types::String,
          required: true,
          description: 'Full path of the upstream project of the Project Subscription.'

        field :subscription,
          Types::Ci::Subscriptions::ProjectType,
          null: true,
          description: "Project Subscription created by the mutation."

        def resolve(project_path:, upstream_path:)
          project = authorized_find!(project_path)

          upstream_project = find_and_authorize_upstream_project!(upstream_path)

          response = ::Ci::CreateProjectSubscriptionService.new(
            project: project,
            upstream_project: upstream_project,
            user: current_user
          ).execute

          if response.error?
            result(errors: response.errors)
          else
            result(subscription: response.payload[:subscription])
          end
        end

        private

        def find_and_authorize_upstream_project!(upstream_path)
          upstream_project = find_object(upstream_path)
          if upstream_project && current_user.can?(:subscribe_to_upstream_pipeline, upstream_project)
            return upstream_project
          end

          raise_resource_not_available_error!
        end

        def result(subscription: nil, errors: [])
          {
            subscription: subscription,
            errors: errors
          }
        end
      end
    end
  end
end
