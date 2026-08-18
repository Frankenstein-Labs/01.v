# frozen_string_literal: true

module QA
  module EE
    module Resource
      module Ai
        class DuoWorkflow < QA::Resource::Base
          FOUNDATIONAL_FLOWS = {
            'developer/v1' => {
              default_goal: 'Create a file hello.txt at the repository root containing: hello from dap'
            }
          }.freeze

          DEFAULT_WORKFLOW_DEFINITION = 'developer/v1'

          attr_accessor :project, :workflow_definition
          attr_writer :goal, :start_workflow
          attr_reader :id, :workload_id, :status, :api_response

          def initialize
            @workflow_definition = DEFAULT_WORKFLOW_DEFINITION
            @start_workflow = true
          end

          def goal
            @goal || flow_config.fetch(:default_goal)
          end

          def api_support?
            true
          end

          def fabricate_via_api!
            @api_response = api_post_to(api_post_path, api_post_body)
            @api_fabrication_http_method = :post
            @id = api_response[:id]
            @workload_id = api_response.dig(:workload, :id)
            @status = api_response[:status]

            api_response[:gitlab_url] || QA::Runtime::Scenario.gitlab_address
          end

          # No per-workflow cleanup: duo_workflows_workflows.project_id has a DB-level
          # ON DELETE CASCADE, so the workflow (and its pipeline/checkpoints) is removed when
          # its project is deleted in the spec teardown.
          def remove_via_api!; end

          def api_post_path
            '/ai/duo_workflows/workflows'
          end

          def api_post_body
            {
              project_id: project.id.to_s,
              workflow_definition: workflow_definition,
              goal: goal,
              start_workflow: @start_workflow
            }
          end

          def workload_pipeline
            project.pipelines.find { |pipeline| pipeline[:source] == 'duo_workflow' }
          end

          def current_status
            response = process_api_response(
              api_post_to(
                '/graphql',
                <<~GQL
                  query {
                    project(fullPath: "#{project.full_path}") {
                      duoWorkflowWorkflows(workflowId: "gid://gitlab/Ai::DuoWorkflows::Workflow/#{id}") {
                        nodes { statusName }
                      }
                    }
                  }
                GQL
              )
            )

            response.dig(:duo_workflow_workflows, :nodes)&.first&.dig(:status_name)
          end

          private

          def flow_config
            FOUNDATIONAL_FLOWS.fetch(workflow_definition) do
              raise ArgumentError,
                "Unknown foundational flow '#{workflow_definition}'. Add it to " \
                  "#{self.class}::FOUNDATIONAL_FLOWS or set #goal explicitly."
            end
          end
        end
      end
    end
  end
end
