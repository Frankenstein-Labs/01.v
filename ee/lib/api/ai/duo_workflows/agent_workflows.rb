# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      # This endpoint is a restricted mirror of POST /ai/duo_workflows/workflows,
      # intended for agents to kick off foundational flows via an ai_workflows-scoped token.
      # It does not accept agent_privileges or pre_approved_agent_privileges, ensuring
      # agents cannot escalate their own privileges when creating workflows.
      class AgentWorkflows < ::API::Base
        include PaginationParams
        include APIGuard

        helpers ::API::Helpers::DuoWorkflowHelpers

        feature_category :duo_agent_platform

        allow_access_with_scope :ai_workflows

        before do
          authenticate!
          not_found! unless Feature.enabled?(:agentic_foundational_flow_tool, current_user)
        end

        helpers do
          def create_workflow_params
            declared_params(include_missing: false).except(
              :start_workflow,
              :source_branch,
              :additional_context,
              :shallow_clone,
              :ai_catalog_item_consumer_id
            ).tap do |wrkf_params|
              if wrkf_params[:ai_catalog_item_version_id]
                wrkf_params[:ai_catalog_item_version] = ::Ai::Catalog::ItemVersion
                                                          .find(wrkf_params.delete(:ai_catalog_item_version_id))
              end

              if wrkf_params[:issue_id] && wrkf_params[:project_id]
                project = find_project!(wrkf_params[:project_id])
                wrkf_params[:issue] = project.issues.find_by_iid!(wrkf_params.delete(:issue_id))
              end

              if wrkf_params[:merge_request_id] && wrkf_params[:project_id]
                project = find_project!(wrkf_params[:project_id])
                wrkf_params[:merge_request] = project.merge_requests.find_by_iid!(wrkf_params.delete(:merge_request_id))
              end
            end
          end

          params :workflow_params do
            optional :project_id, type: String, desc: 'The ID or path of the workflow project',
              documentation: { example: '1' }
            optional :namespace_id, type: String, desc: 'The ID or path of the workflow namespace',
              documentation: { example: '1' }
            optional :ai_catalog_item_consumer_id, type: Integer,
              desc: 'The ID of AI Catalog ItemConsumer that configures which catalog item to execute.',
              documentation: { example: 1 }
            optional :start_workflow, type: Boolean,
              desc: 'Optional parameter to start workflow in a CI pipeline.' \
                'This feature is currently in an experimental state.',
              documentation: { example: true }
            optional :goal, type: String, desc: 'Goal of the workflow',
              documentation: { example: 'Fix pipeline for merge request 1 in project 1' }
            optional :workflow_definition, type: String, desc: 'workflow type based on its capability',
              documentation: { example: 'software_developer' }
            optional :allow_agent_to_request_user, type: Boolean,
              desc: 'When this is enabled Duo Agent Platform may stop to ask the user questions before proceeding. ' \
                'When it is disabled Duo Agent Platform will always just run through the workflow without ever ' \
                'asking for user input. Defaults to true.',
              documentation: { example: true }
            optional :image, type: String, desc: 'Container image to use for running the workflow in CI pipeline.',
              documentation: { example: 'registry.gitlab.com/gitlab-org/duo-workflow/custom-image:latest' }
            optional :source_branch, type: String,
              desc: 'Source branch for the CI pipeline. Uses default branch when not specified.',
              documentation: { example: 'main' }
            optional :environment, type: String,
              values: ::Ai::DuoWorkflows::Workflow.environments.keys.map(&:to_s),
              desc: 'Environment for the workflow.',
              documentation: { example: 'web' }
            optional :ai_catalog_item_version_id, type: Integer,
              desc: 'The ID of AI Catalog ItemVersion that sourced flow config used by the workflow.',
              documentation: { example: 1 }
            optional :additional_context, type: Array,
              desc: 'Additional Context required by the Flow, in JSON format. Contains an array of context details, ' \
                'where each detail is a Hash with a minimum of "Category" and "Content" keys.',
              documentation: {
                example: '[{"Category": "agent_user_environment", "Content": "{\"merge_request_url\": ' \
                  'https://gitlab.com/project/-/merge_requests/1\"}", "Metadata": "{}"}]'
              } do
                requires :Category, type: String, desc: 'The category of the context detail'
                requires :Content, type: String, desc: 'The content type of the context detail'
              end
            optional :shallow_clone, type: Boolean,
              desc: 'Whether or not the workflow should use a shallow clone of the repository during its execution.  ' \
                'Defaults to true.',
              default: true,
              documentation: { example: true }
            optional :issue_id, type: Integer,
              desc: 'IID of the Issue noteable that the workflow is associated with.',
              documentation: { example: 123 }
            optional :merge_request_id, type: Integer,
              desc: 'IID of the MergeRequest noteable that the workflow is associated with.',
              documentation: { example: 123 }
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            namespace :agent_workflows do
              desc 'Create workflow persistence (agent-initiated, limited privileges)' do
                tags ['gitlab_duo_workflows']
                detail 'Accessible via ai_workflows scope token. ' \
                  'Does not accept agent_privileges or pre_approved_agent_privileges.'
                success code: 201
                failure [
                  { code: 400, message: 'Validation failed' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: '403 Forbidden' },
                  { code: 404, message: 'Not found' }
                ]
              end
              params do
                use :workflow_params
              end
              route_setting :authorization, skip_granular_token_authorization: :ai_workflows_oauth_auth
              route_setting :lifecycle, :experiment
              post do
                ::Gitlab::QueryLimiting.disable!(
                  'https://gitlab.com/gitlab-org/gitlab/-/issues/566195', new_threshold: 125
                )

                container = if params[:project_id]
                              find_project!(params[:project_id])
                            elsif params[:namespace_id]
                              find_namespace!(params[:namespace_id])
                            else
                              current_user.default_duo_namespace
                            end

                if container.nil?
                  bad_request!('No default namespace found. Please provide project_id or namespace_id, ' \
                    'or configure a default Duo namespace.')
                end

                forbidden!('Access to the container is not allowed') unless container_access_allowed?(container)

                if params[:ai_catalog_item_consumer_id]
                  unless container.is_a?(Project)
                    bad_request!('AI Catalog flows can only be executed in project context')
                  end

                  consumer = find_item_consumer!(params[:ai_catalog_item_consumer_id], container)

                  service_account = if consumer.project.present?
                                      consumer.parent_item_consumer&.service_account
                                    else
                                      consumer.service_account
                                    end

                  flow_params = {
                    item_consumer: consumer,
                    service_account: service_account,
                    execute_workflow: params[:start_workflow].present?,
                    event_type: 'api_execution',
                    user_prompt: params[:goal],
                    source_branch: params[:source_branch],
                    additional_context: params[:additional_context]
                  }

                  result = ::Ai::Catalog::Flows::ExecuteService.new(
                    project: container,
                    current_user: current_user,
                    params: flow_params
                  ).execute

                  bad_request!(result.message) if result.error?

                  workflow = result.payload[:workflow]
                  workload_id = result.payload[:workload_id]

                  present workflow, with: ::API::Entities::Ai::DuoWorkflows::Workflow,
                    workload: { id: workload_id, message: result.message }
                else
                  workflow_params = create_workflow_params

                  # A running agent is the caller here, so the run is always background.
                  # This endpoint's caller holds an ai_workflows-scoped token rather than a
                  # user's own, so it can never be the one performing the run.
                  execution = authorize_flow_execution!(
                    workflow_params, container,
                    caller_can_execute: false,
                    start_workflow: params[:start_workflow].present?,
                    item_consumer_id: params[:ai_catalog_item_consumer_id]
                  )

                  workflow_params[:agent_privileges] = ::Ai::DuoWorkflows::Workflow::AgentPrivileges::DEFAULT_PRIVILEGES

                  service = ::Ai::DuoWorkflows::CreateWorkflowService.new(
                    container: container, current_user: current_user, params: workflow_params,
                    execution: execution)

                  result = service.execute

                  forbidden!(result.message) if result.error? && result.http_status == :forbidden
                  not_found!(result.message) if result.error? && result.http_status == :not_found
                  if result.error? && result.http_status == :payment_required
                    forbidden!("session failed to start due to insufficient GitLab credits. " \
                      "Purchase more credits to continue.")
                  end

                  bad_request!(result[:message]) if result[:status] == :error

                  push_ai_gateway_headers(scope: container,
                    subject: workflow_params[:service_account] || current_user)

                  if params[:start_workflow].present?
                    response = ::Ai::DuoWorkflows::StartWorkflowService.new(
                      workflow: result[:workflow],
                      params: start_workflow_params(result[:workflow].id, container: container,
                        service_account: workflow_params[:service_account])
                    ).execute

                    if response.error?
                      status_code = case response.reason
                                    when :unprocessable_entity
                                      :unprocessable_entity
                                    when :feature_unavailable, :invalid_service_account
                                      :forbidden
                                    when :workload_failure
                                      :unprocessable_entity
                                    else
                                      :internal_server_error
                                    end
                      render_api_error!(response.message, status_code)
                    else
                      workload_id = response.payload && response.payload[:workload_id]
                      message = response.message
                    end
                  end

                  present result[:workflow], with: ::API::Entities::Ai::DuoWorkflows::Workflow,
                    workload: { id: workload_id, message: message }
                end
              end
            end
          end
        end
      end
    end
  end
end
