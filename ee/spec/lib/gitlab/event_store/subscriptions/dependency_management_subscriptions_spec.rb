# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::EventStore::Subscriptions::DependencyManagementSubscriptions,
  feature_category: :dependency_management do
  let(:store) do
    Gitlab::EventStore::Store.new do |store|
      described_class.new(store).register
    end
  end

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:service_account) do
    create(:user, :service_account,
      name: DependencyManagement::ProvisionServiceAccountService::SERVICE_ACCOUNT_NAME)
  end

  context 'for MergeRequests::MergedEvent' do
    let(:worker) { DependencyManagement::SecurityUpdate::TrackMergedMrWorker }

    let(:merge_request) do
      create(:merge_request,
        source_project: project,
        target_project: project,
        author: author,
        source_branch: source_branch)
    end

    let(:merge_request_id) { merge_request.id }

    subject(:publish) { store.publish(MergeRequests::MergedEvent.new(data: { merge_request_id: merge_request_id })) }

    context 'when the MR is a dep-management auto-remediation MR' do
      let(:author) { service_account }
      let(:source_branch) { 'dependency-management/rack-3.x' }

      it 'schedules the worker' do
        expect(worker).to receive(:perform_async)

        publish
      end
    end

    context 'when the source branch is not a dep-management branch' do
      let(:author) { service_account }
      let(:source_branch) { 'feature/some-change' }

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end

    context 'when the author is not a service account' do
      let(:author) do
        create(:user, name: DependencyManagement::ProvisionServiceAccountService::SERVICE_ACCOUNT_NAME)
      end

      let(:source_branch) { 'dependency-management/rack-3.x' }

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end

    context 'when the author is a service account with a different name' do
      let(:author) { create(:user, :service_account, name: 'Some Other Bot') }
      let(:source_branch) { 'dependency-management/rack-3.x' }

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end

    context 'when the merge request does not exist' do
      let(:author) { service_account }
      let(:source_branch) { 'dependency-management/rack-3.x' }
      let(:merge_request_id) { non_existing_record_id }

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end
  end

  context 'for MergeRequests::ClosedEvent' do
    let_it_be(:merge_request) do
      create(:merge_request, source_project: project, target_project: project)
    end

    let(:worker) { DependencyManagement::SecurityUpdate::TrackClosedMrWorker }
    let(:source) { MergeRequests::ClosedEvent::SOURCE_TYPES[:dependency_management_auto_remediation] }
    let(:event_data) do
      {
        merge_request_id: merge_request.id,
        source: source
      }
    end

    subject(:publish) { store.publish(MergeRequests::ClosedEvent.new(data: event_data)) }

    context 'when the event source is dependency management auto-remediation' do
      it 'schedules the worker' do
        expect(worker).to receive(:perform_async)

        publish
      end
    end

    context 'when the event source is not present' do
      let(:event_data) { { merge_request_id: merge_request.id } }

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end

    context 'when the event source is a different type' do
      let(:source) { 'some_other_source' }

      before do
        stub_const(
          'MergeRequests::ClosedEvent::SOURCE_TYPES',
          MergeRequests::ClosedEvent::SOURCE_TYPES.merge(some_other_source: source)
        )
      end

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end
  end

  context 'for Ci::PipelineFinishedEvent' do
    let(:worker) { DependencyManagement::SecurityUpdate::TriggerResolveDependencyBumpWorkflowWorker }
    let(:author) { service_account }
    let(:source_branch) { "#{DependencyManagement::SecurityUpdate::Request::BRANCH_PREFIX}/foo-1.x" }
    let(:merge_request) do
      create(:merge_request, source_project: project, target_project: project, author: author,
        source_branch: source_branch)
    end

    let(:pipeline) do
      create(:ci_pipeline, project: project, merge_request: merge_request, status: :failed,
        source: :merge_request_event, ref: merge_request.ref_path)
    end

    subject(:publish) do
      store.publish(Ci::PipelineFinishedEvent.new(data: { pipeline_id: pipeline.id, status: pipeline.status }))
    end

    context 'when a dep-bump service account MR pipeline fails and the flag is enabled' do
      it 'schedules the worker' do
        expect(worker).to receive(:perform_async)

        publish
      end
    end

    context 'when the failure is on a branch pipeline for a dependency-management branch' do
      let(:pipeline) do
        create(:ci_pipeline, project: project, status: :failed, ref: source_branch)
      end

      it 'schedules the worker' do
        expect(worker).to receive(:perform_async)

        publish
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(enable_dependency_bump_breaking_changes: false)
      end

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end

    context 'when the pipeline did not fail' do
      let(:pipeline) { create(:ci_pipeline, project: project, merge_request: merge_request, status: :success) }

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end

    context 'when the MR source branch is not a dependency-management branch' do
      let(:source_branch) { 'some-feature-branch' }

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end

    context 'when a branch pipeline ref is not a dependency-management branch' do
      let(:pipeline) do
        create(:ci_pipeline, project: project, status: :failed, ref: 'master')
      end

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end
  end

  context 'for Ci::PipelineFinishedEvent pipeline tracking' do
    let(:worker) { DependencyManagement::SecurityUpdate::TrackResolveDependencyBumpPipelineWorker }
    let(:source_branch) { "#{DependencyManagement::SecurityUpdate::Request::BRANCH_PREFIX}/foo-1.x" }
    let(:merge_request) do
      create(:merge_request, source_project: project, target_project: project, author: service_account,
        source_branch: source_branch)
    end

    let(:pipeline) do
      create(:ci_pipeline, project: project, merge_request: merge_request, status: :success,
        source: :merge_request_event, ref: merge_request.ref_path)
    end

    let(:pipeline_id) { pipeline.id }

    subject(:publish) do
      store.publish(Ci::PipelineFinishedEvent.new(data: { pipeline_id: pipeline_id, status: pipeline.status }))
    end

    context 'when a dep-bump MR pipeline succeeds and the flag is enabled' do
      it 'schedules the worker' do
        expect(worker).to receive(:perform_async)

        publish
      end
    end

    context 'when the pipeline failed' do
      let(:pipeline) do
        create(:ci_pipeline, project: project, merge_request: merge_request, status: :failed,
          source: :merge_request_event, ref: merge_request.ref_path)
      end

      it 'schedules the worker' do
        expect(worker).to receive(:perform_async)

        publish
      end
    end

    context 'when the pipeline is a branch pipeline for a dependency-management branch' do
      let(:pipeline) do
        create(:ci_pipeline, project: project, status: :success, ref: source_branch)
      end

      it 'schedules the worker' do
        expect(worker).to receive(:perform_async)

        publish
      end
    end

    context 'when the pipeline tracking feature flag is disabled' do
      before do
        stub_feature_flags(enable_dependency_bump_breaking_changes_pipeline_tracking: false)
      end

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end

    context 'when the MR source branch is not a dependency-management branch' do
      let(:source_branch) { 'some-feature-branch' }

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end

    context 'when a branch pipeline ref is not a dependency-management branch' do
      let(:pipeline) do
        create(:ci_pipeline, project: project, status: :success, ref: 'master')
      end

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end

    context 'when the pipeline does not exist' do
      let(:pipeline_id) { non_existing_record_id }

      it 'does not schedule the worker' do
        expect(worker).not_to receive(:perform_async)

        publish
      end
    end
  end
end
