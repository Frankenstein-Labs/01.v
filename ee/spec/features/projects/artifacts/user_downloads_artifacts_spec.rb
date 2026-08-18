# frozen_string_literal: true

require "spec_helper"

RSpec.describe "User downloads artifacts", feature_category: :job_artifacts do
  let_it_be(:project) { create(:project, :repository, :public) }
  let_it_be(:pipeline) { create(:ci_empty_pipeline, status: :success, sha: project.commit.id, project: project) }
  let_it_be(:job) { create(:ci_build, :artifacts, :success, pipeline: pipeline) }

  shared_examples "downloading" do
    it "audits the download" do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(name: 'job_artifact_downloaded'))

      visit(url)
    end
  end

  context "when downloading" do
    before do
      stub_licensed_features(
        admin_audit_log: true,
        audit_events: true,
        extended_audit_events: true,
        external_audit_events: true)
    end

    context "with job id" do
      let(:url) { download_project_job_artifacts_path(project, job) }

      it_behaves_like "downloading"
    end

    context "with branch name and job name" do
      let(:url) { latest_succeeded_project_artifacts_path(project, "#{pipeline.ref}/download", job: job.name) }

      it_behaves_like "downloading"
    end

    context "with SHA" do
      let(:url) { latest_succeeded_project_artifacts_path(project, "#{pipeline.sha}/download", job: job.name) }

      it_behaves_like "downloading"
    end

    context "when unauthorized" do
      let(:url) { download_project_job_artifacts_path(project, job) }

      before do
        job.job_artifacts.update_all(accessibility: 'private')
      end

      it 'does not audit when no-one can download' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        visit(url)
      end
    end
  end
end
