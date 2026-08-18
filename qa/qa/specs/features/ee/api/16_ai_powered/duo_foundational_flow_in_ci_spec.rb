# frozen_string_literal: true

module QA
  RSpec.describe 'Ai-powered', feature_category: :duo_agent_platform do
    describe 'Duo Agent Platform foundational flow in CI' do
      let(:workload_tag) { 'gitlab--duo' }
      let(:flow_reference) { 'developer/v1' }
      let(:goal) { ENV['QA_DUO_FLOW_GOAL'] }
      let(:admin_api_client) { Runtime::User::Store.admin_api_client }
      let(:owner) { create(:user, :with_personal_access_token, api_client: admin_api_client) }
      let(:api_client) { owner.api_client }

      let(:group) do
        QA::Resource::Sandbox.fabricate_via_api! do |sandbox|
          sandbox.api_client = admin_api_client
          sandbox.path = "dap-flow-group-#{SecureRandom.hex(4)}"
        end
      end

      let(:project) do
        QA::Resource::Project.fabricate_via_api! do |project|
          project.api_client = api_client
          project.group = group
          project.name = "dap-flow-project-#{SecureRandom.hex(4)}"
          project.initialize_with_readme = true
          project.description = 'Duo Agent Platform foundational flow CI smoke test'
        end
      end

      let(:runner) do
        # Duo Agent Platform jobs may only run on instance-wide or top-level group runners
        create(:group_runner,
          api_client: api_client,
          group: group,
          name: "dap-flow-runner-#{SecureRandom.hex(4)}",
          tags: [workload_tag],
          executor: :docker)
      end

      before do
        # Admin creates the top-level group, then grants the non-admin user Owner on it so the
        # remaining Duo Agent Platform setup runs as that Owner (api_client). Admin also assigns
        # the Owner a Duo seat, required for the create_duo_workflow entitlement gate.
        group.add_member(owner, Resource::Members::AccessLevel::OWNER)
        EE::Flow::FoundationalFlow.assign_duo_seat!(owner, api_client: admin_api_client)

        EE::Flow::FoundationalFlow.enable_on_group!(group, flow_reference: flow_reference, api_client: api_client)
        project
        EE::Flow::FoundationalFlow.enable_remote_flows_on_project!(project, api_client: api_client)

        EE::Flow::FoundationalFlow.wait_for_flow_consumer!(group, project, flow_reference: flow_reference,
          api_client: api_client)

        runner.wait_until_online
      end

      after do
        runner&.remove_via_api!
        project&.remove_via_api!
        group&.remove_via_api!
      end

      context 'on Self-managed', :orchestrated, :duo_agent_platform, :requires_admin do
        it 'runs the foundational flow to completion in a CI pipeline' do
          workflow = nil
          Support::Retrier.retry_until(
            max_duration: 300,
            sleep_interval: 5,
            message: 'Wait for Duo Agent Platform provisioning so the workflow can be created'
          ) do
            workflow = EE::Resource::Ai::DuoWorkflow.fabricate_via_api! do |flow|
              flow.api_client = api_client
              flow.project = project
              flow.workflow_definition = flow_reference
              flow.goal = goal
            end
            true
          rescue QA::Resource::Errors::ResourceFabricationFailedError => e
            raise unless e.message.include?('(403)')

            false
          end

          expect(workflow.id).not_to be_nil, 'Expected the workflow to be created and started'

          # Wait for the workload pipeline (source: duo_workflow) to be created, then to succeed.
          Support::Waiter.wait_until(
            message: 'Wait for duo_workflow pipeline to be created',
            max_duration: 120,
            sleep_interval: 5
          ) { workflow.workload_pipeline }

          pipeline = workflow.workload_pipeline

          Flow::Pipeline.wait_for_pipeline_to_have_status_by_id(
            project: project,
            pipeline_id: pipeline[:id],
            status: 'success',
            wait: 600
          )

          terminal_statuses = %w[finished failed stopped]
          workflow_status = nil
          Support::Waiter.wait_until(
            message: 'Wait for workflow to reach a terminal status',
            max_duration: 60,
            sleep_interval: 5
          ) { terminal_statuses.include?(workflow_status = workflow.current_status) }

          expect(workflow_status).to eq('finished'),
            "Expected workflow to finish, but its status was '#{workflow_status}'"
        end
      end
    end
  end
end
