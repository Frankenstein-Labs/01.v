# frozen_string_literal: true

module Types
  module Users
    class DuoStatusType < BaseObject
      graphql_name 'UserDuoStatus'
      description 'Represents the Duo status for a user.'

      authorize :read_user

      field :disabled, GraphQL::Types::Boolean, null: false,
        description: 'Indicates if the user is disabled for assignment in Duo features.'
      field :disabled_reason, GraphQL::Types::String, null: true,
        description: 'Reason why the user is disabled for assignment in Duo features.'
      field :flow_trigger_events, [Types::Ai::FlowTrigger::EventTypeEnum], null: false,
        description: 'List of available flow trigger events for the user in Duo features.'

      def flow_trigger_events
        filtered_triggers.flat_map(&:event_types).uniq
      end

      def disabled
        agent_status_check_result.disabled?
      end

      def disabled_reason
        agent_status_check_result.disabled_reason
      end

      private

      def agent_status_check_result
        @agent_status_check_result ||= ::Ai::Agents::CheckAgentStatusService.new(current_user).execute(object)
      end

      def parent_entity
        @parent_entity ||= context[:duo_status_parent]
      end

      def filtered_triggers
        triggers = (object.ai_flow_triggers + object.child_item_consumers_flow_triggers).uniq

        # Apply in-memory filtering to use any preloaded records.
        case parent_entity
        when ::Project
          triggers.select do |trigger|
            trigger.project_id == parent_entity.id
          end
        when ::Namespace
          project_ids = parent_entity.project_ids

          triggers.select do |trigger|
            trigger.project_id.in?(project_ids)
          end
        else
          triggers
        end
      end
    end
  end
end
