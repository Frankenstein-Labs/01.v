# frozen_string_literal: true

module Ai
  module Catalog
    module Onboarding
      class ExecuteDeveloperGoalService < Ai::Catalog::BaseService
        def initialize(project:, current_user:, params: {})
          @event_type = params[:event_type]
          super
        end

        def execute
          consumer = developer_v1_consumer
          goal = ::Ai::Catalog::GoalTemplates::Developer.resolve(
            event_type: event_type,
            resource: project,
            user_input: nil,
            params: { triggered_by_username: current_user.username }
          )

          ::Ai::Catalog::Flows::ExecuteService.new(
            project: project,
            current_user: current_user,
            params: {
              item_consumer: consumer,
              user_prompt: goal,
              event_type: 'web',
              execute_workflow: true,
              service_account: consumer&.active_service_account
            }
          ).execute
        end

        private

        attr_reader :event_type

        def developer_v1_consumer
          catalog_item = ::Ai::Catalog::FoundationalFlow['developer/v1'].catalog_item
          catalog_item&.consumers&.for_projects(project)&.first
        end
      end
    end
  end
end
