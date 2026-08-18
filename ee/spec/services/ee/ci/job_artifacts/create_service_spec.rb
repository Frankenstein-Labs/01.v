# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobArtifacts::CreateService, :clean_gitlab_redis_shared_state, feature_category: :job_artifacts do
  let_it_be(:project) { create(:project, :small_repo) }

  let(:pipeline) { create(:ci_pipeline, project: project, ref: project.default_branch) }
  let(:service) { described_class.new(job) }
  let(:job) { create(:ci_build, project: project, pipeline: pipeline, ref: project.default_branch) }
  let(:artifacts_sha256) { '0' * 64 }
  let(:metadata_file) { nil }

  let(:artifacts_file) do
    file_to_upload('spec/fixtures/ci_build_artifacts.zip', sha256: artifacts_sha256)
  end

  let(:params) do
    {
      'artifact_type' => 'archive',
      'artifact_format' => 'zip'
    }.with_indifferent_access
  end

  def file_to_upload(path, params = {})
    upload = Tempfile.new('upload')
    FileUtils.copy(path, upload.path)
    # This is a workaround for https://github.com/docker/for-linux/issues/1015
    FileUtils.touch(upload.path)

    UploadedFile.new(upload.path, **params)
  end

  def unique_metrics_report_uploaders
    Gitlab::UsageDataCounters::HLLRedisCounter.unique_events(
      event_names: described_class::METRICS_REPORT_UPLOAD_EVENT_NAME,
      start_date: 2.weeks.ago,
      end_date: 2.weeks.from_now
    )
  end

  describe '#execute' do
    subject(:execute_service) { service.execute(artifacts_file, params, metadata_file: metadata_file) }

    context 'when artifacts file is uploaded' do
      it 'does not track the job user_id' do
        subject

        expect(unique_metrics_report_uploaders).to eq(0)
      end
    end

    context 'when artifact_type is metrics' do
      before do
        allow(job).to receive(:user_id).and_return(123)
      end

      let(:params) { { 'artifact_type' => 'metrics', 'artifact_format' => 'gzip' }.with_indifferent_access }

      it 'tracks the job user_id' do
        subject

        expect(unique_metrics_report_uploaders).to eq(1)
      end
    end

    context 'when artifact_type is sast' do
      let(:params) { { 'artifact_type' => 'sast' }.with_indifferent_access }

      before do
        allow(job).to receive(:user_id).and_return(123)
      end

      context 'when the artifact is for project default branch' do
        it 'triggers the adherence worker' do
          expect(::ComplianceManagement::Standards::Gitlab::SastWorker).to receive(:perform_async)
            .with({ 'project_id' => project.id, 'user_id' => 123 })

          subject
        end
      end

      context 'when the artifact is not for project default branch' do
        let(:merge_request) do
          create(
            :merge_request, source_project: project
          )
        end

        let(:pipeline) { create(:ci_pipeline, :detached_merge_request_pipeline, merge_request: merge_request) }

        let(:job) { create(:ci_build, pipeline: pipeline, project: project) }

        it 'does not trigger the adherence worker' do
          expect(::ComplianceManagement::Standards::Gitlab::SastWorker).not_to receive(:perform_async)

          subject
        end
      end
    end

    context 'when artifact_type is dast' do
      let(:params) { { 'artifact_type' => 'dast' }.with_indifferent_access }

      before do
        allow(job).to receive(:user_id).and_return(123)
      end

      context 'when the artifact is for project default branch' do
        it 'triggers the adherence worker' do
          expect(::ComplianceManagement::Standards::Gitlab::DastWorker).to receive(:perform_async)
            .with({ 'project_id' => project.id, 'user_id' => 123 })

          subject
        end
      end

      context 'when the artifact is not for project default branch' do
        let(:merge_request) do
          create(
            :merge_request, source_project: project
          )
        end

        let(:pipeline) { create(:ci_pipeline, :detached_merge_request_pipeline, merge_request: merge_request) }

        let(:job) { create(:ci_build, pipeline: pipeline, project: project) }

        it 'does not trigger the adherence worker' do
          expect(::ComplianceManagement::Standards::Gitlab::DastWorker).not_to receive(:perform_async)

          subject
        end
      end
    end
  end
end
