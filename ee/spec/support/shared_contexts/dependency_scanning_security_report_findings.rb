# frozen_string_literal: true

RSpec.shared_context 'with dependency scanning security report findings' do
  let_it_be(:yarn_lock_content, freeze: false) { fixture_file('security_reports/remediations/yarn.lock', dir: 'ee') }
  let_it_be(:project_files, freeze: false) { { 'yarn.lock' => yarn_lock_content } }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, :custom_repo, namespace: group, files: project_files) }
  let_it_be(:pipeline, freeze: false) { create(:ci_pipeline, :success, project: project) }
  let_it_be(:tracked_context, freeze: false) do
    create(:security_project_tracked_context, :default, project: project, context_name: pipeline.ref)
  end

  let_it_be(:build, freeze: false) { create(:ci_build, :success, name: 'dependency_scanning', pipeline: pipeline) }
  let_it_be(:artifact, freeze: false) { create(:ee_ci_job_artifact, :dependency_scanning_remediation, job: build) }
  let_it_be(:report, freeze: false) { create(:dependency_scanning_security_report, pipeline: pipeline) }
  let_it_be(:report_finding, freeze: false) { report.findings.second }
end
