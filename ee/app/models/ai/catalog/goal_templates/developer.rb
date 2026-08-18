# frozen_string_literal: true

module Ai
  module Catalog
    module GoalTemplates
      class Developer < Base
        def self.resolve(event_type:, resource:, user_input:, params: {})
          raise ArgumentError, 'resource must not be nil' unless resource

          handler = handler_for(event_type, resource, params)
          interpolate(handler.template, vars: handler.vars(resource: resource, params: params), user_input: user_input)
        end

        def self.handler_for(event_type, resource, params = {})
          case event_type
          when :init_project_context then Developer::InitProjectContext
          when :improve_ci           then Developer::ImproveCi
          when :init_execution_env   then Developer::InitExecutionEnv
          when :init_mr_review_instructions then Developer::InitMrReviewInstructions
          when :init_codeowners      then Developer::InitCodeowners
          when :init_chat_rules      then Developer::InitChatRules
          when :mention              then Developer::Mention
          when :assign_reviewer      then Developer::AssignMergeRequestReview
          when :merge_request
            # Only `merged` has a Developer template. Other merge_request actions (for example
            # `approved`, dispatched by ExecuteMergeRequestApprovedWorkflowTriggersWorker) must not
            # silently fall through to the merged template and tell the agent the MR was merged.
            return Developer::MergedMergeRequest if params[:action].to_s == 'merged'

            raise ArgumentError,
              "Unsupported merge request action for Developer goal template: #{params[:action].inspect}"
          when :assign
            resource.is_a?(MergeRequest) ? Developer::AssignMergeRequest : Developer::AssignIssue
          else
            raise ArgumentError, "Unsupported event type for Developer goal template: #{event_type.inspect}"
          end
        end

        def self.resource_display_name(resource)
          case resource
          when MergeRequest then 'merge request'
          when WorkItem then 'work item'
          when Issue then 'issue'
          else resource.class.name.demodulize.underscore.humanize(capitalize: false)
          end
        end
      end
    end
  end
end
