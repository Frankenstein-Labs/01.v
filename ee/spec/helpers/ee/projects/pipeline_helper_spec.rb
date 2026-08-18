# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::PipelineHelper, feature_category: :pipeline_composition do
  include Ci::BuildsHelper
  include Devise::Test::ControllerHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:raw_pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project, ref: 'master', sha: project.commit.id) }
  # `freeze: false` is kept here because this `let_it_be` subject is not an
  # ActiveRecord record (or memoizes internal state); freezing raises
  # FrozenError and reload/refind are no-ops on it. Keep as-is (see
  # gitlab-org/gitlab#602925).
  let_it_be(:pipeline, freeze: false) { Ci::PipelinePresenter.new(raw_pipeline, current_user: user) }

  describe '#js_pipeline_tabs_data' do
    before do
      project.add_developer(user)
    end

    subject(:pipeline_tabs_data) { helper.js_pipeline_tabs_data(project, pipeline, user) }

    it 'returns pipeline tabs data' do
      expect(pipeline_tabs_data).to include({
        can_generate_codequality_reports: pipeline.can_generate_codequality_reports?.to_json,
        can_manage_licenses: 'false',
        codequality_report_download_path: helper.codequality_report_download_path(project, pipeline),
        expose_license_scanning_data: helper.expose_license_scanning_data?(project, pipeline).to_json,
        expose_security_dashboard: pipeline.expose_security_dashboard?.to_json,
        is_full_codequality_report_available: project.licensed_feature_available?(:full_codequality_report).to_json,
        license_management_api_url: license_management_api_url(project),
        licenses_api_path: helper.licenses_api_path(project, pipeline),
        failed_jobs_count: pipeline.failed_builds.count,
        project_path: project.full_path,
        graphql_resource_etag: graphql_etag_pipeline_path(pipeline),
        metrics_path: namespace_project_ci_prometheus_metrics_histograms_path(namespace_id: project.namespace, project_id: project, format: :json),
        pipeline_iid: pipeline.iid,
        pipeline_path: pipeline_path(pipeline),
        pipeline_project_path: project.full_path,
        security_policies_path: kind_of(String),
        total_job_count: pipeline.total_size,
        sbom_reports_errors: '[]',
        validity_checks_enabled: project.security_setting.validity_checks_enabled.to_json
      })
      expect(Gitlab::Json.parse(pipeline_tabs_data[:vulnerability_report_data])).to include({
        "empty_state_svg_path" => match_asset_path("illustrations/user-not-logged-in.svg"),
        "pipeline_id" => pipeline.id,
        "pipeline_iid" => pipeline.iid,
        "source_branch" => pipeline.source_ref,
        "pipeline_jobs_path" => "/api/v4/projects/#{project.id}/pipelines/#{pipeline.id}/jobs",
        "vulnerability_exports_endpoint" => "/api/v4/security/projects/#{project.id}/vulnerability_exports",
        "project_full_path" => project.path_with_namespace,
        "can_admin_vulnerability" => 'false',
        "can_view_false_positive" => 'false'
      })
    end

    context 'when project security_setting is nil' do
      before do
        allow(project).to receive(:security_setting).and_return(nil)
      end

      it 'returns pipeline tabs data with validity_checks_enabled as false' do
        expect(pipeline_tabs_data[:validity_checks_enabled]).to eq('false')
      end
    end

    describe 'dismissal descriptions' do
      let(:dismissal_descriptions_json) do
        # Use dynamic translations via N_(...)
        {
          acceptable_risk: _("The vulnerability is known, and has not been remediated or mitigated, but is considered to be an acceptable business risk."),
          false_positive: _("An error in reporting in which a test result incorrectly indicates the presence of a vulnerability in a system when the vulnerability is not present."),
          mitigating_control: _("A management, operational, or technical control (that is, safeguard or countermeasure) employed by an organization that provides equivalent or comparable protection for an information system."),
          used_in_tests: _("The finding is not a vulnerability because it is part of a test or is test data."),
          not_applicable: _("The vulnerability is known, and has not been remediated or mitigated, but is considered to be in a part of the application that will not be updated.")
        }.to_json
      end

      it 'includes translated dismissal descriptions' do
        Gitlab::I18n.with_locale(:zh_CN) do
          expect(pipeline_tabs_data[:dismissal_descriptions]).to eq(dismissal_descriptions_json)
        end
      end
    end

    context 'with sbom reports errors' do
      let(:sbom_errors) { [["Unsupported CycloneDX spec version. Must be one of: 1.4, 1.5"]] }

      before do
        allow(pipeline).to receive(:sbom_report_ingestion_errors).and_return(sbom_errors)
      end

      it 'includes sbom reports errors' do
        expect(pipeline_tabs_data[:sbom_reports_errors]).to eq(sbom_errors.to_json)
      end
    end
  end

  describe 'codequality_report_download_path' do
    before do
      project.add_developer(user)
    end

    subject(:codequality_report_path) { helper.codequality_report_download_path(project, pipeline) }

    describe 'when `full_codequality_report` feature is not available' do
      before do
        stub_licensed_features(full_codequality_report: false)
      end

      it 'returns nil' do
        is_expected.to be_nil
      end
    end

    describe 'when `full_code_quality_report` feature is available' do
      before do
        stub_licensed_features(full_codequality_report: true)
      end

      describe 'and there is no artefact for codequality' do
        it 'returns nil for `codequality`' do
          is_expected.to be_nil
        end
      end

      describe 'and there is an artefact for codequality' do
        before do
          create(:ci_build, :codequality_report, pipeline: raw_pipeline)
        end

        it 'returns the downloadable path for `codequality`' do
          is_expected.not_to be_nil
          is_expected.to eq(pipeline.downloadable_path_for_report_type(:codequality))
        end
      end
    end
  end

  describe 'licenses_api_path' do
    before do
      project.add_developer(user)
    end

    subject(:licenses_api_path) { helper.licenses_api_path(project, pipeline) }

    describe 'when `license_scanning` feature is not available' do
      before do
        stub_licensed_features(license_scanning: false)
      end

      it 'returns nil' do
        is_expected.to be_nil
      end
    end

    describe 'when `license_scanning` feature is available' do
      before do
        stub_licensed_features(license_scanning: true)
      end

      it 'returns the licenses api path' do
        is_expected.to eq(licenses_project_pipeline_path(project, pipeline))
      end
    end
  end

  describe 'expose_license_scanning_data?' do
    before do
      project.add_developer(user)
    end

    subject(:expose_license_scanning_data?) { helper.expose_license_scanning_data?(project, pipeline) }

    describe 'when `license_scanning` feature is not available' do
      before do
        stub_licensed_features(license_scanning: false)
      end

      it 'returns false' do
        is_expected.to be(false)
      end
    end

    describe 'when `license_scanning` feature is available' do
      before do
        stub_licensed_features(license_scanning: true)
      end

      it 'returns true' do
        is_expected.to be(true)
      end
    end
  end

  describe 'vulnerability_report_data' do
    before do
      project.add_developer(user)
    end

    subject(:vulnerability_report_data) { helper.vulnerability_report_data(project, pipeline, user) }

    it "returns the vulnerability report's data" do
      expect(vulnerability_report_data).to include({
        empty_state_svg_path: match_asset_path("illustrations/user-not-logged-in.svg"),
        pipeline_id: pipeline.id,
        pipeline_iid: pipeline.iid,
        source_branch: pipeline.source_ref,
        pipeline_jobs_path: "/api/v4/projects/#{project.id}/pipelines/#{pipeline.id}/jobs",
        vulnerability_exports_endpoint: "/api/v4/security/projects/#{project.id}/vulnerability_exports",
        project_full_path: project.path_with_namespace,
        can_admin_vulnerability: 'false',
        can_view_false_positive: 'false'
      })
    end
  end

  describe '#js_pipeline_header_data' do
    before do
      project.add_developer(user)
      allow(helper).to receive(:current_user).and_return(user)
    end

    subject(:pipeline_header_data) { helper.js_pipeline_header_data(project, pipeline) }

    it 'returns pipeline header data' do
      expect(pipeline_header_data).to include({
        full_path: project.full_path,
        graphql_resource_etag: graphql_etag_pipeline_path(pipeline),
        pipeline_iid: pipeline.iid,
        pipelines_path: project_pipelines_path(project),
        identity_verification_required: 'false',
        identity_verification_path: identity_verification_path,
        merge_trains_available: 'false',
        can_read_merge_train: 'true',
        merge_trains_path: project_merge_trains_path(project)
      })
    end

    describe 'identity_verification_required field' do
      using RSpec::Parameterized::TableSyntax

      # `freeze: false` is kept here because this `let_it_be` subject is not an
      # ActiveRecord record (or memoizes internal state); freezing raises
      # FrozenError and reload/refind are no-ops on it. Keep as-is (see
      # gitlab-org/gitlab#602925).
      let_it_be(:pipeline, freeze: false) { create(:ci_empty_pipeline, project: project, status: 'failed', user: user) }

      subject(:identity_verification_required) { pipeline_header_data[:identity_verification_required] }

      where(:user_not_verified?, :can_run_jobs?, :result) do
        false | false | false
        false | true  | false
        true  | false | true
        true  | true  | false
      end

      with_them do
        before do
          allow(helper).to receive(:current_user).and_return(user)

          allow(pipeline).to receive(:user_not_verified?).and_return(user_not_verified?)

          init_params = { user: user, project: project }
          allow_next_instance_of(Users::IdentityVerification::AuthorizeCi, init_params) do |instance|
            allow(instance).to receive(:user_can_run_jobs?).and_return(can_run_jobs?)
          end
        end

        it { is_expected.to eq(result.to_s) }
      end
    end

    context 'when pipeline is a merge request event pipeline' do
      let_it_be(:merge_request) do
        create(:merge_request, source_project: project)
      end

      let_it_be(:raw_pipeline) do
        create(:ci_pipeline,
          project: project,
          ref: 'master',
          sha: project.commit.id,
          merge_request: merge_request)
      end

      # `freeze: false` is kept here because this `let_it_be` subject is not an
      # ActiveRecord record (or memoizes internal state); freezing raises
      # FrozenError and reload/refind are no-ops on it. Keep as-is (see
      # gitlab-org/gitlab#602925).
      let_it_be(:pipeline, freeze: false) do
        Ci::PipelinePresenter.new(raw_pipeline, current_user:
          user)
      end

      it 'includes the merge request path' do
        expect(pipeline_header_data).to include(
          merge_request_path: project_merge_request_path(project,
            merge_request.iid)
        )
      end
    end

    context 'when pipeline is a branch pipeline with an associated open merge
    request' do
      let_it_be(:branch_merge_request) do
        create(:merge_request, source_project: project, source_branch: 'feature',
          target_branch: 'master')
      end

      let_it_be(:raw_pipeline) do
        create(:ci_pipeline,
          project: project,
          ref: branch_merge_request.source_branch,
          sha: branch_merge_request.diff_head_sha)
      end

      # `freeze: false` is kept here because this `let_it_be` subject is not an
      # ActiveRecord record (or memoizes internal state); freezing raises
      # FrozenError and reload/refind are no-ops on it. Keep as-is (see
      # gitlab-org/gitlab#602925).
      let_it_be(:pipeline, freeze: false) do
        Ci::PipelinePresenter.new(raw_pipeline, current_user:
          user)
      end

      it 'falls back to the associated open merge request' do
        expect(pipeline_header_data).to include(
          merge_request_path: project_merge_request_path(project,
            branch_merge_request.iid)
        )
      end
    end

    context 'when pipeline is a branch pipeline with no associated merge request' do
      it 'returns nil for merge request path' do
        expect(pipeline_header_data).to include(merge_request_path: nil)
      end
    end
  end
end
