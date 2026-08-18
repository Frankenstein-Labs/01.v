# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::TriggerResolveDependencyBumpWorkflowWorker,
  feature_category: :dependency_management do
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:owner) { project.first_owner }
  let_it_be(:dep_management_sa) do
    create(:user, :service_account, name: 'GitLab Dependency Management').tap do |sa|
      sa.user_detail.update!(provisioned_by_project: project)
      project.add_member(sa, :guest)
    end
  end

  let_it_be(:merge_request) do
    create(:merge_request, source_project: project, target_project: project, author: dep_management_sa,
      source_branch: "#{DependencyManagement::SecurityUpdate::Request::BRANCH_PREFIX}/foo-1.x")
  end

  let_it_be(:pipeline) do
    create(:ci_pipeline, project: project, merge_request: merge_request, status: :failed)
  end

  let(:workflow_definition) { 'resolve_dependency_bump/experimental' }
  let_it_be(:consumer) { create(:ai_catalog_item_consumer, project: project) }
  let(:execute_service) { instance_double(::Ai::Catalog::Flows::ExecuteService) }
  let(:service_result) do
    ServiceResponse.success(payload: { workflow_id: 1, workload_id: 2 })
  end

  let(:event) do
    ::Ci::PipelineFinishedEvent.new(data: { pipeline_id: pipeline.id, status: 'failed' })
  end

  subject(:handle_event) { described_class.new.handle_event(event) }

  before do
    project.project_setting.update!(
      duo_dependency_bump_breaking_changes_enabled: true,
      duo_dependency_bump_breaking_changes_enabled_by: owner
    )
    allow(::Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
      instance_double(::Ai::Catalog::ItemConsumersFinder, execute: [consumer])
    )
    allow(::Ai::Catalog::Flows::ExecuteService).to receive(:new).and_return(execute_service)
    allow(execute_service).to receive(:execute).and_return(service_result)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(owner, :duo_workflow, anything).and_return(true)
    allow_next_found_instance_of(Project) do |found_project|
      allow(found_project).to receive(:duo_dependency_bump_breaking_changes_available?).and_return(true)
    end
  end

  it_behaves_like 'subscribes to event'

  describe '#handle_event' do
    context 'when the flow is not available for the project' do
      before do
        allow_next_found_instance_of(Project) do |found_project|
          allow(found_project).to receive(:duo_dependency_bump_breaking_changes_available?).and_return(false)
        end
      end

      it 'returns early without calling the workflow service' do
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

        handle_event
      end
    end

    context 'when pipeline does not exist' do
      let(:event) do
        ::Ci::PipelineFinishedEvent.new(data: { pipeline_id: non_existing_record_id, status: 'failed' })
      end

      it 'returns early' do
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

        handle_event
      end
    end

    context 'when pipeline has no associated open merge request' do
      let_it_be(:pipeline_without_mr) do
        create(:ci_pipeline, project: project, status: :failed, ref: 'branch-without-mr')
      end

      let(:event) do
        ::Ci::PipelineFinishedEvent.new(data: { pipeline_id: pipeline_without_mr.id, status: 'failed' })
      end

      it 'returns early' do
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

        handle_event
      end
    end

    context 'when MR author is not the dependency management service account' do
      let_it_be(:other_mr) do
        create(:merge_request, source_project: project, target_project: project, author: owner,
          source_branch: 'other-branch')
      end

      let_it_be(:other_pipeline) do
        create(:ci_pipeline, project: project, merge_request: other_mr, status: :failed)
      end

      let(:event) do
        ::Ci::PipelineFinishedEvent.new(data: { pipeline_id: other_pipeline.id, status: 'failed' })
      end

      it 'returns early' do
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

        handle_event
      end
    end

    context 'when an in-flight workflow already exists for the MR' do
      before do
        create(:duo_workflows_workflow, :running,
          project: project,
          merge_request: merge_request,
          user: owner,
          workflow_definition: workflow_definition)
      end

      it 'returns early without enqueueing another workflow' do
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

        handle_event
      end
    end

    context 'when iteration cap is reached' do
      before do
        create_list(:duo_workflows_workflow, described_class::MAX_ITERATIONS, :finished,
          project: project,
          merge_request: merge_request,
          user: owner,
          workflow_definition: workflow_definition)
      end

      it 'returns early without enqueueing another workflow' do
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

        handle_event
      end
    end

    context 'when the enabler is missing' do
      before do
        project.project_setting.update!(duo_dependency_bump_breaking_changes_enabled_by: nil)
      end

      it 'disables the setting, logs an error and returns early' do
        expect(::Gitlab::AppLogger).to receive(:error).with(
          hash_including(message: match(/Enabler for resolve_dependency_bump setting is missing/))
        )
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

        expect { handle_event }
          .to change { project.project_setting.reload.duo_dependency_bump_breaking_changes_enabled }
          .from(true).to(false)
      end
    end

    context 'when the enabler is not authorized to execute the flow' do
      before do
        allow(Ability).to receive(:allowed?).with(owner, :duo_workflow, anything).and_return(false)
      end

      it 'disables the setting, logs an error and returns early' do
        expect(::Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: match(/Enabler is not authorized/),
            user_id: owner.id
          )
        )
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

        expect { handle_event }
          .to change { project.project_setting.reload.duo_dependency_bump_breaking_changes_enabled }
          .from(true).to(false)
      end
    end

    context 'when no consumer is found' do
      before do
        allow(::Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
          instance_double(::Ai::Catalog::ItemConsumersFinder, execute: [])
        )
        allow(::Gitlab::AppLogger).to receive(:info).and_call_original
      end

      it 'logs an info message and returns early' do
        expect(::Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: match(/No consumer found/),
            workflow_definition: workflow_definition
          )
        )
        expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

        handle_event
      end
    end

    context 'when all preconditions are met' do
      shared_examples 'executes the workflow with the resolved service account' do
        it 'executes the workflow with the setting enabler as current_user' do
          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project,
            current_user: owner,
            params: hash_including(
              item_consumer: consumer,
              service_account: expected_service_account,
              execute_workflow: true,
              event_type: 'sidekiq_worker',
              merge_request_id: merge_request.iid,
              user_prompt: ::Gitlab::Routing.url_helpers.project_pipeline_url(project, pipeline),
              source_branch: merge_request.source_branch,
              additional_context: [
                {
                  "Category" => "merge_request",
                  "Content" => ::Gitlab::Json.dump({ "url" => ::Gitlab::UrlBuilder.build(merge_request) })
                }
              ]
            )
          )

          handle_event
        end
      end

      context 'with a project-level consumer' do
        let(:consumer) { create(:ai_catalog_item_consumer, :child_item_consumer) }
        let(:expected_service_account) { consumer.parent_item_consumer.service_account }

        it_behaves_like 'executes the workflow with the resolved service account'
      end

      context 'with a group-level consumer' do
        let(:consumer) { create(:ai_catalog_item_consumer, :parent_item_consumer) }
        let(:expected_service_account) { consumer.service_account }

        it_behaves_like 'executes the workflow with the resolved service account'
      end

      it 'tracks the workflow trigger as an internal event' do
        expect { handle_event }
          .to trigger_internal_events('trigger_resolve_dependency_bump_workflow')
          .with(
            project: project,
            additional_properties: {
              label: 'automatic',
              value: merge_request.id,
              property: '1'
            }
          )
      end

      context 'when a previous workflow already ran for the MR' do
        before do
          create(:duo_workflows_workflow, :finished,
            project: project,
            merge_request: merge_request,
            user: owner,
            workflow_definition: workflow_definition)
        end

        it 'records the iteration number in the property' do
          expect { handle_event }
            .to trigger_internal_events('trigger_resolve_dependency_bump_workflow')
            .with(
              project: project,
              additional_properties: {
                label: 'automatic',
                value: merge_request.id,
                property: '2'
              }
            )
        end
      end
    end

    context 'when the workflow service fails' do
      let(:service_result) do
        ServiceResponse.error(message: 'Workflow creation failed', reason: :invalid_params)
      end

      it 'does not track the trigger event' do
        expect { handle_event }
          .not_to trigger_internal_events('trigger_resolve_dependency_bump_workflow')
      end

      it 'logs the error and does not raise' do
        expect(::Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'Failed to call resolve_dependency_bump workflow service',
            merge_request_id: merge_request.id,
            project_id: project.id,
            error_message: 'Workflow creation failed',
            failure_reason: :invalid_params
          )
        )

        expect { handle_event }.not_to raise_error
      end
    end
  end
end
