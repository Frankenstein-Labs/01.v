# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class ExecuteService < Ai::Catalog::BaseService
        include Gitlab::Utils::StrongMemoize
        include Loggable

        def initialize(project:, current_user:, params:)
          @item_consumer = params[:item_consumer]
          @execute_workflow = params[:execute_workflow]
          @event_type = params[:event_type]
          @triggering_conversation = params[:triggering_conversation]
          @user_prompt = params[:user_prompt]
          @service_account = params[:service_account]
          @source_branch = params[:source_branch]
          @additional_context = params[:additional_context]
          @issue_id = params[:issue_id]
          @merge_request_id = params[:merge_request_id]
          @resume_context = params[:resume_context]
          @messaging_callback_context = params[:messaging_callback_context]

          if @item_consumer
            @flow = @item_consumer.item
            @flow_version = @flow&.resolve_version(@item_consumer.pinned_version_prefix)

            ai_catalog_logger.context(
              consumer: @item_consumer,
              item: @flow,
              version: @flow_version
            )
          end

          super
        end

        def execute
          return validate unless validate.success?
          return error_no_permissions unless allowed?

          flow_config = generate_flow_config

          return ServiceResponse.success(payload: { flow_config: flow_config.to_yaml }) unless execute_workflow

          execution_result = execute_workflow_service(flow_config)

          if execution_result.success?
            track_ai_item_events(
              'trigger_ai_catalog_item',
              item_execution_properties(item: flow, version: flow_version).merge(
                label: flow.item_type, property: event_type, value: flow.id
              )
            )
            ai_catalog_logger.info(message: 'Flow executed')
          end

          execution_result
        end

        private

        attr_reader :flow, :flow_version, :event_type, :user_prompt, :execute_workflow, :item_consumer, :service_account

        def allowed?
          Ability.allowed?(current_user, :execute_ai_catalog_item, item_consumer)
        end

        def validate
          return error('Item consumer is required') unless item_consumer
          return error('Item consumer must be associated with a flow') unless flow
          return error('Item must be a flow type') unless flow.flow?
          return error('Trigger event type is required') if event_type.blank?

          ServiceResponse.success
        end
        strong_memoize_attr :validate

        def execute_workflow_service(flow_config)
          params = {
            json_config: flow_config,
            container: item_consumer.project,
            goal: flow_goal,
            item_version: flow_version,
            service_account: service_account,
            flow_definition: fetch_flow_definition,
            title: fetch_flow_title,
            source_branch: @source_branch,
            additional_context: @additional_context,
            event_type: @event_type,
            triggering_conversation: @triggering_conversation,
            issue_id: @issue_id,
            merge_request_id: @merge_request_id,
            resume_context: @resume_context,
            messaging_callback_context: @messaging_callback_context
          }.merge(resolved_foundational_flow_params)

          ::Ai::Catalog::ExecuteWorkflowService.new(current_user, params).execute
        end

        def resolved_foundational_flow_params
          return {} unless foundational_flow?

          ::Ai::DuoWorkflows::FoundationalFlowStartParamsResolver.call(
            flow.foundational_flow_reference, item_consumer.project, user: current_user
          )
        end

        def foundational_flow?
          @item_consumer.item&.foundational?
        end

        def generate_flow_config
          return if foundational_flow?

          flow_version.definition.except('yaml_definition')
        end

        def flow_goal
          user_prompt || flow.description
        end

        def fetch_flow_definition
          return unless foundational_flow?

          flow.foundational_flow_reference
        end

        def fetch_flow_title
          return if foundational_flow?

          flow.name
        end
      end
    end
  end
end
