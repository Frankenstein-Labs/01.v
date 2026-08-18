# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::CreateMergeRequestWorker,
  feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }

  let_it_be(:pipeline) do
    create(:ci_pipeline, :success,
      project: project,
      source: :dependency_management_security_update
    )
  end

  let_it_be(:build) { create(:ci_build, :success, pipeline: pipeline) }

  let(:event) do
    Ci::PipelineFinishedEvent.new(data: { pipeline_id: pipeline.id, status: 'success' })
  end

  let(:vulnerability_id) { vulnerability.id.to_s }

  subject(:handle_event) { described_class.new.handle_event(event) }

  it_behaves_like 'subscribes to event'

  describe '#handle_event' do
    before do
      stub_licensed_features(dependency_scanning: true)

      allow(Ci::Pipeline).to receive(:find_by_id).and_call_original
      allow(Ci::Pipeline).to receive(:find_by_id).with(pipeline.id).and_return(pipeline)
      allow(pipeline).to receive(:find_job_with_archive_artifacts)
        .with('workload')
        .and_return(build)
      allow(build).to receive(:variables).and_return(
        Gitlab::Ci::Variables::Collection.new([
          { key: 'DEPENDENCY_MANAGEMENT_VULNERABILITY_ID', value: vulnerability_id }
        ])
      )
    end

    context 'when the pipeline succeeded and vulnerability exists' do
      it 'calls CreateMergeRequestService with correct arguments' do
        expect_next_instance_of(
          DependencyManagement::SecurityUpdate::CreateMergeRequestService,
          project: project, pipeline: pipeline, vulnerability: vulnerability
        ) do |service|
          expect(service).to receive(:execute)
            .and_return(ServiceResponse.success(payload: { merge_request: build_stubbed(:merge_request) }))
        end

        handle_event
      end
    end

    context 'when the service skips a user-dismissed remediation' do
      it 'does not raise (no merge request in the payload)' do
        expect_next_instance_of(
          DependencyManagement::SecurityUpdate::CreateMergeRequestService,
          project: project, pipeline: pipeline, vulnerability: vulnerability
        ) do |service|
          expect(service).to receive(:execute).and_return(ServiceResponse.success(payload: { skipped: true }))
        end

        expect { handle_event }.not_to raise_error
      end
    end

    context 'when the pipeline is not a dependency_management_security_update source' do
      let(:pipeline) { create(:ci_pipeline, :success, project: project, source: :push) }

      it 'does not call the service' do
        expect(DependencyManagement::SecurityUpdate::CreateMergeRequestService).not_to receive(:new)

        handle_event
      end
    end

    context 'when the pipeline failed' do
      let(:pipeline) do
        create(:ci_pipeline, :failed,
          project: project,
          source: :dependency_management_security_update
        )
      end

      it 'does not call the service' do
        expect(DependencyManagement::SecurityUpdate::CreateMergeRequestService).not_to receive(:new)

        handle_event
      end
    end

    context 'when the pipeline does not exist' do
      let(:event) { Ci::PipelineFinishedEvent.new(data: { pipeline_id: non_existing_record_id, status: 'success' }) }

      it 'does not call the service' do
        expect(DependencyManagement::SecurityUpdate::CreateMergeRequestService).not_to receive(:new)

        handle_event
      end
    end

    context 'when job containing artificat does not exist' do
      before do
        allow(pipeline).to receive(:find_job_with_archive_artifacts)
          .with('workload')
          .and_return(nil)
      end

      it 'does not call the service' do
        expect(DependencyManagement::SecurityUpdate::CreateMergeRequestService).not_to receive(:new)

        handle_event
      end

      it 'logs an error' do
        expect(Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'DependencyManagement::SecurityUpdate::CreateMergeRequestWorker: job producing artifact not found',
            pipeline_id: pipeline.id,
            project_id: project.id
          )
        )

        handle_event
      end
    end

    context 'when the vulnerability_id variable is missing' do
      let(:vulnerability_id) { nil }

      it 'does not call the service' do
        expect(DependencyManagement::SecurityUpdate::CreateMergeRequestService).not_to receive(:new)

        handle_event
      end
    end

    context 'when the vulnerability does not belong to the project' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_vulnerability) { create(:vulnerability, :with_finding, project: other_project) }

      let(:vulnerability_id) { other_vulnerability.id.to_s }

      it 'does not call the service' do
        expect(DependencyManagement::SecurityUpdate::CreateMergeRequestService).not_to receive(:new)
        handle_event
      end
    end

    context 'when the licensed feature is unavailable' do
      before do
        stub_licensed_features(dependency_scanning: false)
      end

      it 'does not call the service' do
        expect(DependencyManagement::SecurityUpdate::CreateMergeRequestService).not_to receive(:new)

        handle_event
      end
    end

    context 'when the service returns an error' do
      it 'logs the error without raising' do
        allow_next_instance_of(DependencyManagement::SecurityUpdate::CreateMergeRequestService) do |svc|
          allow(svc).to receive(:execute)
            .and_return(ServiceResponse.error(message: 'something went wrong'))
        end

        expect(Gitlab::AppLogger).to receive(:error).with(
          hash_including(
            message: 'DependencyManagement::SecurityUpdate: failed to create merge request',
            reason: 'something went wrong'
          )
        )

        expect { handle_event }.not_to raise_error
      end
    end
  end

  describe 'subscriptions' do
    context 'when the event carries the pipeline source' do
      context 'when source is dependency_management_security_update' do
        it_behaves_like 'subscribes to event' do
          let(:event) do
            Ci::PipelineFinishedEvent.new(data: {
              pipeline_id: pipeline.id, status: 'success', source: 'dependency_management_security_update'
            })
          end
        end
      end

      context 'when source is not dependency_management_security_update' do
        it_behaves_like 'ignores the published event' do
          let(:event) do
            Ci::PipelineFinishedEvent.new(data: { pipeline_id: pipeline.id, status: 'success', source: 'push' })
          end
        end
      end
    end

    context 'when the event does not carry the pipeline source' do
      context 'when pipeline is a dependency_management_security_update' do
        it_behaves_like 'subscribes to event' do
          let(:event) { Ci::PipelineFinishedEvent.new(data: { pipeline_id: pipeline.id, status: 'success' }) }
        end
      end

      context 'when pipeline is not a dependency_management_security_update' do
        let_it_be(:other_pipeline) { create(:ci_pipeline, :success, project: project, source: :push) }

        it_behaves_like 'ignores the published event' do
          let(:event) { Ci::PipelineFinishedEvent.new(data: { pipeline_id: other_pipeline.id, status: 'success' }) }
        end
      end

      context 'when the event carries a partition_id' do
        it_behaves_like 'subscribes to event' do
          let(:event) do
            Ci::PipelineFinishedEvent.new(data: {
              pipeline_id: pipeline.id, status: 'success', partition_id: pipeline.partition_id
            })
          end
        end

        it_behaves_like 'ignores the published event' do
          let(:event) do
            Ci::PipelineFinishedEvent.new(data: {
              pipeline_id: pipeline.id, status: 'success', partition_id: pipeline.partition_id + 1
            })
          end
        end
      end
    end
  end
end
