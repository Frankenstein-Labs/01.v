# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Otel::CreateWorkflowService, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:service_account) { create(:user) }

  let(:service) { described_class.new(project: project, current_user: user) }

  let(:consumer) do
    instance_double(Ai::Catalog::ItemConsumer, project: nil, service_account: service_account,
      item: nil, pinned_version_prefix: nil)
  end

  let(:finder_double) do
    instance_double(Ai::Catalog::ItemConsumersFinder, execute: [consumer])
  end

  shared_examples 'returns an error' do |message|
    it 'returns error' do
      expect(execute).to be_error
      expect(execute.message).to eq(message)
    end
  end

  shared_examples 'closes the issue on failure' do
    it 'closes the issue' do
      expect_next_instance_of(Issues::CloseService) do |svc|
        expect(svc).to receive(:execute).with(issue)
      end

      execute
    end
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    let(:issue) { create(:issue, project: project) }
    let(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
    let(:workload_id) { 'workload-abc-123' }

    before do
      allow(Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(finder_double)
    end

    context 'when no item consumer is found for developer/v1' do
      before do
        allow(Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
          instance_double(Ai::Catalog::ItemConsumersFinder, execute: [])
        )
      end

      include_examples 'returns an error', 'Could not find enabled developer flow for this project'
    end

    context 'when service account is nil' do
      before do
        allow(Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
          instance_double(Ai::Catalog::ItemConsumersFinder,
            execute: [instance_double(Ai::Catalog::ItemConsumer, project: project, parent_item_consumer: nil)])
        )
      end

      include_examples 'returns an error', 'Could not resolve the service account for this flow'
    end

    context 'when user is authorized and item consumer exists' do
      context 'when issue creation fails' do
        before do
          allow_next_instance_of(Issues::CreateService) do |svc|
            allow(svc).to receive(:execute).and_return(
              ServiceResponse.error(message: ['Title is too long'])
            )
          end
        end

        include_examples 'returns an error', ['Title is too long']
      end

      context 'when issue creation succeeds' do
        before do
          allow_next_instance_of(Issues::CreateService) do |svc|
            allow(svc).to receive(:execute).and_return(
              ServiceResponse.success(payload: { issue: issue })
            )
          end
        end

        context 'when flow execution fails' do
          before do
            allow_next_instance_of(Ai::Catalog::Flows::ExecuteService) do |svc|
              allow(svc).to receive(:execute).and_return(
                ServiceResponse.error(message: 'Flow execution failed')
              )
            end
          end

          include_examples 'returns an error', 'Flow execution failed'
          include_examples 'closes the issue on failure'
        end

        context 'when project has no repository languages' do
          before do
            allow(project).to receive(:repository_languages).and_return([])
            allow_next_instance_of(Ai::Catalog::Flows::ExecuteService) do |svc|
              allow(svc).to receive(:execute).and_return(
                ServiceResponse.success(payload: { workflow: workflow, workload_id: workload_id })
              )
            end
          end

          it 'calls GoalTemplates.build_description with nil' do
            expect(::Gitlab::Duo::Otel::GoalTemplates).to receive(:build_description).with(nil)

            execute
          end
        end

        context 'when everything succeeds' do
          before do
            allow_next_instance_of(Ai::Catalog::Flows::ExecuteService) do |svc|
              allow(svc).to receive(:execute).and_return(
                ServiceResponse.success(payload: { workflow: workflow, workload_id: workload_id })
              )
            end
          end

          it 'returns success with issue, workflow, and workload_id' do
            expect(execute).to be_success
            expect(execute.payload[:issue]).to eq(issue)
            expect(execute.payload[:workflow]).to eq(workflow)
            expect(execute.payload[:workload_id]).to eq(workload_id)
          end

          it 'passes correct params to ExecuteService including item_consumer and service_account' do
            expect(Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
              project: project,
              current_user: user,
              params: hash_including(
                item_consumer: consumer,
                service_account: service_account,
                execute_workflow: true,
                event_type: 'otel_execution',
                source_branch: project.default_branch
              )
            ).and_call_original

            execute
          end

          it 'associates the issue with the workflow' do
            execute

            expect(workflow.reload.issue).to eq(issue)
          end

          it 'creates a system note on the issue' do
            expect(SystemNoteService).to receive(:agent_session_started)
              .with(issue, project, workflow.id, user, service_account)

            execute
          end

          it 'does not close the issue' do
            expect(Issues::CloseService).not_to receive(:new)

            execute
          end
        end

        context 'when associate_issue fails' do
          before do
            allow_next_instance_of(Ai::Catalog::Flows::ExecuteService) do |svc|
              allow(svc).to receive(:execute).and_return(
                ServiceResponse.success(payload: { workflow: workflow, workload_id: workload_id })
              )
            end
            allow(workflow).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
          end

          include_examples 'returns an error', 'Failed to associate issue with workflow'
          include_examples 'closes the issue on failure'

          it 'tracks the exception' do
            expect(::Gitlab::ErrorTracking).to receive(:track_exception)
              .with(instance_of(ActiveRecord::RecordInvalid), workflow_id: workflow.id)

            execute
          end
        end
      end
    end

    context 'when item_consumer belongs to a project (resolves service_account via parent)' do
      let(:parent_consumer) do
        instance_double(Ai::Catalog::ItemConsumer, service_account: service_account)
      end

      let(:project_consumer) do
        instance_double(Ai::Catalog::ItemConsumer, project: project, parent_item_consumer: parent_consumer,
          item: nil, pinned_version_prefix: nil)
      end

      before do
        allow(Ai::Catalog::ItemConsumersFinder).to receive(:new).and_return(
          instance_double(Ai::Catalog::ItemConsumersFinder, execute: [project_consumer])
        )
        allow_next_instance_of(Issues::CreateService) do |svc|
          allow(svc).to receive(:execute).and_return(
            ServiceResponse.success(payload: { issue: issue })
          )
        end
        allow_next_instance_of(Ai::Catalog::Flows::ExecuteService) do |svc|
          allow(svc).to receive(:execute).and_return(
            ServiceResponse.success(payload: { workflow: workflow, workload_id: workload_id })
          )
        end
      end

      it 'resolves service_account via parent_item_consumer and succeeds' do
        expect(execute).to be_success
        expect(execute.payload[:issue]).to eq(issue)
      end
    end
  end

  describe '#primary_language' do
    subject(:primary_language) { service.send(:primary_language) }

    context 'when the project has repository languages' do
      it 'returns the highest-share language name' do
        ruby = create(:programming_language, name: 'Ruby')
        go = create(:programming_language, name: 'Go')

        create(:repository_language, project: project, programming_language: ruby, share: 40.0)
        create(:repository_language, project: project, programming_language: go, share: 60.0)

        expect(primary_language).to eq('Go')
      end
    end

    context 'when the project has no repository languages' do
      it 'returns nil' do
        expect(primary_language).to be_nil
      end
    end
  end
end
