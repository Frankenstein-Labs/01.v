# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Build, :saas, feature_category: :continuous_integration do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group_with_plan, plan: :bronze_plan) }

  let_it_be_with_refind(:project) { create(:project, :small_repo, group: group) }

  let_it_be_with_refind(:pipeline) do
    create(
      :ci_pipeline,
      project: project,
      sha: project.commit.id,
      ref: project.default_branch,
      status: 'success'
    )
  end

  let_it_be(:stage) { create(:ci_stage) }
  let(:job) { create(:ee_ci_build, pipeline: pipeline) }
  let(:artifact) { create(:ee_ci_job_artifact, :sast, job: job, project: job.project) }
  let_it_be(:valid_secrets) do
    {
      DATABASE_PASSWORD: {
        vault: {
          engine: { name: 'kv-v2', path: 'kv-v2' },
          path: 'production/db',
          field: 'password'
        }
      }
    }
  end

  it_behaves_like 'a deployable job in EE' do
    let(:job) { job }
  end

  describe '.with_security_reports_of_type' do
    subject(:builds) { described_class.with_reports_of_type(report_to_filter) }

    before_all do
      Enums::Ci::JobArtifact.security_report_file_types.each do |type|
        create(:ee_ci_job_artifact, type.to_sym)
      end
    end

    shared_examples 'it only includes builds of provided report type' do |report_type|
      let(:report_to_filter) { report_type }
      let(:result) { builds.flat_map { |b| b.job_artifacts.security_reports.flat_map(&:file_type) } }

      it "filters by the given report type: #{report_type}" do
        expect(result).to contain_exactly(report_type)
      end
    end

    Enums::Ci::JobArtifact.security_report_file_types.each do |type|
      it_behaves_like 'it only includes builds of provided report type', type
    end
  end

  describe '.license_scan' do
    subject(:build) { described_class.license_scan.first }

    let(:artifact) { build.job_artifacts.first }

    context 'with new license_scanning artifact' do
      let!(:license_artifact) { create(:ee_ci_job_artifact, :license_scanning, job: job, project: job.project) }

      it { expect(artifact.file_type).to eq 'license_scanning' }
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:security_scans).class_name('Security::Scan').with_foreign_key(:build_id) }
    it { is_expected.to have_one(:dast_site_profiles_build).class_name('Dast::SiteProfilesBuild').with_foreign_key(:ci_build_id) }
    it { is_expected.to have_one(:dast_site_profile).class_name('DastSiteProfile').through(:dast_site_profiles_build) }
    it { is_expected.to have_one(:dast_scanner_profiles_build).class_name('Dast::ScannerProfilesBuild').with_foreign_key(:ci_build_id) }
    it { is_expected.to have_one(:dast_scanner_profile).class_name('DastScannerProfile').through(:dast_scanner_profiles_build) }
  end

  describe '#cost_factor_enabled?', feature_category: :hosted_runners do
    subject { job.cost_factor_enabled? }

    before do
      allow(::Gitlab::CurrentSettings).to receive(:shared_runners_minutes).and_return(400)
    end

    context 'with shared runner' do
      before do
        job.runner = create(:ci_runner, :instance)
      end

      it { is_expected.to be_truthy }
    end

    context 'with project runner' do
      before do
        job.runner = create(:ci_runner, :project, projects: [job.project])
      end

      it { is_expected.to be_falsey }
    end

    context 'without runner' do
      it { is_expected.to be_falsey }
    end
  end

  describe 'updates compute minutes', feature_category: :hosted_runners do
    let(:job) { create(:ee_ci_build, :running, pipeline: pipeline) }

    context 'when cancelling supported' do
      %w[success drop cancel].each do |event|
        it "for event #{event}" do
          expect(Ci::Minutes::UpdateBuildMinutesService)
            .to receive(:new).and_call_original

          job.public_send(event)
        end
      end
    end

    context 'when failure reason is server_timeout_running' do
      let(:timeout) { 10 }
      let(:started_before) { timeout + 5 }
      let(:runner) { create(:ci_runner, :instance, :online) }
      let(:job) do
        create(:ee_ci_build,
          :running,
          started_at: started_before.seconds.ago,
          pipeline: pipeline,
          timeout: timeout,
          runner: runner)
      end

      it 'overwrites finished_at and calculates minutes', :sidekiq_inline do
        expect(Ci::Minutes::UpdateBuildMinutesService)
          .to receive(:new).and_call_original

        job.drop!(:server_timeout_running)
        expect(job.reload.finished_at).to eq(job.started_at + timeout.seconds)
        expect(Ci::Minutes::NamespaceMonthlyUsage.first.shared_runners_duration).to eq(timeout)
      end
    end

    context 'when failure reason is not server_timeout_running' do
      let(:timeout) { 10 }
      let(:started_before) { timeout + 5 }
      let(:runner) { create(:ci_runner, :instance, :online) }
      let(:job) do
        create(:ee_ci_build,
          :running,
          started_at: started_before.seconds.ago,
          pipeline: pipeline,
          timeout: timeout,
          runner: runner)
      end

      it 'does not overwrite finished_at', :freeze_time, :sidekiq_inline do
        expect(Ci::Minutes::UpdateBuildMinutesService)
          .to receive(:new).and_call_original

        job.drop!
        expect(job.reload.finished_at).to eq(job.started_at + started_before.seconds)
        expect(Ci::Minutes::NamespaceMonthlyUsage.first.shared_runners_duration).to eq(started_before)
      end
    end

    describe 'transition canceling => canceled' do
      context 'when failure reason is server_timeout_canceling and job is canceling' do
        let(:timeout) { 10 }
        let(:started_before) { timeout + 5 }
        let(:runner) { create(:ci_runner, :instance, :online) }
        let(:job) do
          create(:ee_ci_build,
            :canceling,
            started_at: started_before.seconds.ago,
            pipeline: pipeline,
            timeout: timeout,
            runner: runner)
        end

        it 'overwrites finished_at and calculates minutes', :sidekiq_inline do
          expect(Ci::Minutes::UpdateBuildMinutesService)
            .to receive(:new).and_call_original

          job.drop!(:server_timeout_canceling)
          expect(job.reload.finished_at).to eq(job.started_at + timeout.seconds)
          expect(Ci::Minutes::NamespaceMonthlyUsage.first.shared_runners_duration).to eq(timeout)
        end
      end

      context 'when failure reason is not server_timeout_canceling and job is canceling',
        :freeze_time,
        :sidekiq_inline do
        let(:timeout) { 10 }
        let(:started_before) { timeout + 5 }
        let(:runner) { create(:ci_runner, :instance, :online) }
        let(:job) do
          create(:ee_ci_build,
            :canceling,
            started_at: started_before.seconds.ago,
            pipeline: pipeline,
            timeout: timeout,
            runner: runner)
        end

        it 'does not overwrite finished_at' do
          expect(Ci::Minutes::UpdateBuildMinutesService)
            .to receive(:new).and_call_original

          job.drop!(:server_timeout_running)
          expect(job.reload.finished_at).to eq(job.started_at + started_before.seconds)
          expect(Ci::Minutes::NamespaceMonthlyUsage.first.shared_runners_duration).to eq(started_before)
        end

        context 'when no failure reason is provided' do
          it 'does not overwrite finished_at' do
            expect(Ci::Minutes::UpdateBuildMinutesService)
              .to receive(:new).and_call_original

            job.drop!
            expect(job.reload.finished_at).to eq(job.started_at + started_before.seconds)
            expect(Ci::Minutes::NamespaceMonthlyUsage.first.shared_runners_duration).to eq(started_before)
          end
        end
      end
    end

    # TODO: ensure minutes are still tracked when set to
    # canceled but not when transitioning to canceling
    %w[success drop].each do |event|
      it "for event #{event}" do
        expect(Ci::Minutes::UpdateBuildMinutesService)
          .to receive(:new).and_call_original

        job.public_send(event)
      end

      it 'updates minutes after canceling transitions to canceled' do
        expect(Ci::Minutes::UpdateBuildMinutesService)
          .to receive(:new).and_call_original

        job.cancel
        job.drop
      end
    end
  end

  describe '#variables' do
    subject { job.variables }

    context 'when environment specific variable is defined' do
      let(:environment_variable) do
        { key: 'ENV_KEY', value: 'environment', public: false, masked: false }
      end

      before do
        job.update!(environment: 'staging')
        create(:environment, name: 'staging', project: job.project)

        variable = build(
          :ci_variable,
          environment_variable.slice(:key, :value).merge(project: project, environment_scope: 'stag*')
        )

        variable.save!
      end

      context 'when there is a plan for the group' do
        it 'GITLAB_FEATURES should include the features for that plan' do
          expect(subject.to_runner_variables).to include({ key: 'GITLAB_FEATURES', value: anything, public: true, masked: false })
          features_variable = subject.find { |v| v[:key] == 'GITLAB_FEATURES' }
          expect(features_variable[:value]).to include('multiple_ldap_servers')
        end
      end

      describe 'dast' do
        let_it_be(:project) { create(:project, :small_repo) }
        let_it_be(:user) { create(:user, maintainer_of: project) }
        let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project) }
        let_it_be(:dast_scanner_profile) { create(:dast_scanner_profile, project: project) }
        let_it_be(:dast_site_profile_secret_variable) { create(:dast_site_profile_secret_variable, :password, dast_site_profile: dast_site_profile) }
        let_it_be(:options) { { dast_configuration: { site_profile: dast_site_profile.name, scanner_profile: dast_scanner_profile.name } } }

        before do
          stub_licensed_features(security_on_demand_scans: true)
        end

        shared_examples 'it includes variables' do
          it 'includes variables from the profile' do
            expect(subject.to_runner_variables).to include(*expected_variables.to_runner_variables)
          end
        end

        shared_examples 'it excludes variables' do
          it 'excludes variables from the profile' do
            expect(subject.to_runner_variables).not_to include(*expected_variables.to_runner_variables)
          end
        end

        context 'when there is a dast_site_profile associated with the job' do
          let(:pipeline) { create(:ci_pipeline, project: project) }
          let(:job) { create(:ee_ci_build, :running, pipeline: pipeline, dast_site_profile: dast_site_profile, user: user, options: options) }

          it_behaves_like 'it includes variables' do
            let(:expected_variables) { dast_site_profile.ci_variables }
          end

          context 'when user has permission' do
            it_behaves_like 'it includes variables' do
              let(:expected_variables) { dast_site_profile.secret_ci_variables(user) }
            end
          end
        end

        context 'when there is a dast_scanner_profile associated with the job' do
          let(:pipeline) { create(:ci_pipeline, project: project, user: user) }
          let(:job) { create(:ee_ci_build, :running, pipeline: pipeline, dast_scanner_profile: dast_scanner_profile, options: options) }

          it_behaves_like 'it includes variables' do
            let(:expected_variables) { dast_scanner_profile.ci_variables }
          end
        end

        context 'when there are profiles associated with the job' do
          let(:pipeline) { create(:ci_pipeline, project: project) }
          let(:job) { create(:ee_ci_build, :running, pipeline: pipeline, dast_site_profile: dast_site_profile, dast_scanner_profile: dast_scanner_profile, user: user, options: options) }

          context 'when dast_configuration is absent from the options' do
            let(:options) { {} }

            it 'does not attempt look up any dast profiles to avoid unnecessary queries', :aggregate_failures do
              expect(job).not_to receive(:dast_site_profile)
              expect(job).not_to receive(:dast_scanner_profile)

              subject
            end
          end

          context 'when site_profile is absent from the dast_configuration' do
            let(:options) { { dast_configuration: { scanner_profile: dast_scanner_profile.name } } }

            it 'does not attempt look up the site profile to avoid unnecessary queries' do
              expect(job).not_to receive(:dast_site_profile)

              subject
            end
          end

          context 'when scanner_profile is absent from the dast_configuration' do
            let(:options) { { dast_configuration: { site_profile: dast_site_profile.name } } }

            it 'does not attempt look up the scanner profile to avoid unnecessary queries' do
              expect(job).not_to receive(:dast_scanner_profile)

              subject
            end
          end

          context 'when both profiles are present in the dast_configuration' do
            it 'attempts look up dast profiles', :aggregate_failures do
              expect(job).to receive(:dast_site_profile).and_call_original.at_least(:once)
              expect(job).to receive(:dast_scanner_profile).and_call_original.at_least(:once)

              subject
            end

            context 'when dast_site_profile target_type is website' do
              it_behaves_like 'it includes variables' do
                let(:expected_variables) { dast_scanner_profile.ci_variables(dast_site_profile: dast_site_profile) }
              end
            end

            context 'when dast_site_profile target_type is api' do
              let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project, target_type: 'api') }

              it_behaves_like 'it includes variables' do
                let(:expected_variables) { dast_scanner_profile.ci_variables(dast_site_profile: dast_site_profile) }
              end
            end
          end
        end
      end
    end

    describe 'variable CI_HAS_OPEN_REQUIREMENTS' do
      before do
        stub_licensed_features(requirements: true)
      end

      it "is included with value 'true' if there are open requirements" do
        create(:work_item, :requirement, project: project)

        expect(subject).to include({ key: 'CI_HAS_OPEN_REQUIREMENTS',
                                     value: 'true', public: true, masked: false })
      end

      it 'is not included if there are no open requirements' do
        create(:work_item, :requirement, project: project, state: :closed)

        requirement_variable = subject.find { |var| var[:key] == 'CI_HAS_OPEN_REQUIREMENTS' }

        expect(requirement_variable).to be_nil
      end

      context 'when feature is not available' do
        before do
          stub_licensed_features(requirements: false)
        end

        it 'is not included even if there are open requirements' do
          create(:work_item, :requirement, project: project)

          requirement_variable = subject.find { |var| var[:key] == 'CI_HAS_OPEN_REQUIREMENTS' }

          expect(requirement_variable).to be_nil
        end
      end
    end

    describe 'pages variables', feature_category: :pages do
      before do
        stub_pages_setting(enabled: true)
      end

      it "includes CI_PAGES_* variables" do
        build1 = create(:ee_ci_build, pipeline: pipeline, options: { pages: {} })
        build2 = create(:ee_ci_build, pipeline: pipeline, options: { pages: { path_prefix: 'foo' } })
        build3 = create(:ee_ci_build, pipeline: pipeline, options: { pages: { path_prefix: nil } })
        build4 = create(:ee_ci_build, pipeline: pipeline, options: { pages: { path_prefix: '$CI_COMMIT_BRANCH' } })

        project_namespace, _, project_path = project.full_path.downcase.partition('/')
        ci_pages_hostname = "#{project_namespace}.example.com"
        ci_pages_url = "http://#{ci_pages_hostname}/#{project_path}"

        expect(build1.variables.to_runner_variables).to include(
          { key: 'CI_PAGES_HOSTNAME', value: ci_pages_hostname, public: true, masked: false },
          { key: 'CI_PAGES_URL', value: ci_pages_url, public: true, masked: false }
        )
        expect(build2.variables.to_runner_variables).to include(
          { key: 'CI_PAGES_HOSTNAME', value: ci_pages_hostname, public: true, masked: false },
          { key: 'CI_PAGES_URL', value: "#{ci_pages_url}/foo", public: true, masked: false }
        )
        expect(build3.variables.to_runner_variables).to include(
          { key: 'CI_PAGES_HOSTNAME', value: ci_pages_hostname, public: true, masked: false },
          { key: 'CI_PAGES_URL', value: ci_pages_url, public: true, masked: false }
        )
        expect(build4.variables.to_runner_variables).to include(
          { key: 'CI_PAGES_HOSTNAME', value: ci_pages_hostname, public: true, masked: false },
          { key: 'CI_PAGES_URL', value: "#{ci_pages_url}/master", public: true, masked: false }
        )
      end
    end
  end

  describe '#has_security_reports?' do
    subject { job.has_security_reports? }

    context 'when build has a security report' do
      let!(:artifact) { create(:ee_ci_job_artifact, :sast, job: job, project: job.project) }

      it { is_expected.to be true }
    end

    context 'when build does not have a security report' do
      it { is_expected.to be false }
    end
  end

  describe '#security_job?' do
    subject { job.security_job? }

    context 'when build does not publish artifacts reports' do
      it { is_expected.to be false }
    end

    context 'when build publishes artifacts reports' do
      context 'when build has multiple security report artifact' do
        let(:job) { create(:ee_ci_build, :sast, pipeline: pipeline) }

        it { is_expected.to be true }
      end

      context 'when build has no security report artifacts' do
        let(:job) { create(:ee_ci_build, :coverage_report_cobertura, pipeline: pipeline) }

        it { is_expected.to be false }
      end
    end
  end

  describe '#unmerged_security_reports' do
    subject(:security_reports) { job.unmerged_security_reports }

    context 'when build has a security report' do
      context 'when there is a sast report' do
        let!(:artifact) { create(:ee_ci_job_artifact, :sast, job: job, project: job.project) }

        it 'parses blobs and add the results to the report' do
          expect(security_reports.get_report('sast', artifact).findings.size).to eq(5)
        end
      end

      context 'when there are multiple reports' do
        let!(:sast_artifact) { create(:ee_ci_job_artifact, :sast, job: job, project: job.project) }
        let!(:ds_artifact) { create(:ee_ci_job_artifact, :dependency_scanning, job: job, project: job.project) }
        let!(:cs_artifact) { create(:ee_ci_job_artifact, :container_scanning, job: job, project: job.project) }
        let!(:dast_artifact) { create(:ee_ci_job_artifact, :dast, job: job, project: job.project) }

        it 'parses blobs and adds unmerged results to the reports' do
          expect(security_reports.get_report('sast', sast_artifact).findings.size).to eq(5)
          expect(security_reports.get_report('dependency_scanning', ds_artifact).findings.size).to eq(4)
          expect(security_reports.get_report('container_scanning', cs_artifact).findings.size).to eq(8)
          expect(security_reports.get_report('dast', dast_artifact).findings.size).to eq(24)
        end
      end
    end

    context 'when build has no security reports' do
      it 'has no parsed reports' do
        expect(security_reports.reports).to be_empty
      end
    end
  end

  describe '#collect_security_reports!' do
    let(:security_reports) { ::Gitlab::Ci::Reports::Security::Reports.new(pipeline) }

    before do
      stub_licensed_features(sast: true, dependency_scanning: true, container_scanning: true, dast: true)
    end

    context 'when report types are given' do
      let!(:ds_artifact) { create(:ee_ci_job_artifact, :dependency_scanning, job: job, project: job.project) }
      let!(:cs_artifact) { create(:ee_ci_job_artifact, :container_scanning, job: job, project: job.project) }

      subject { job.collect_security_reports!(security_reports, report_types: %w[container_scanning]) }

      it 'parses blobs and add the results for given report types' do
        subject

        expect(security_reports.get_report('dependency_scanning', ds_artifact).findings.size).to eq(0)
        expect(security_reports.get_report('container_scanning', cs_artifact).findings.size).to eq(8)
      end
    end

    context 'when report types are not given' do
      subject { job.collect_security_reports!(security_reports) }

      context 'when build has a security report' do
        context 'when there is a sast report' do
          let!(:artifact) { create(:ee_ci_job_artifact, :sast, job: job, project: job.project) }

          it 'parses blobs and add the results to the report' do
            subject

            expect(security_reports.get_report('sast', artifact).findings.size).to eq(5)
          end

          it 'adds the created date to the report' do
            subject

            expect(security_reports.get_report('sast', artifact).created_at.to_s).to eq(artifact.created_at.to_s)
          end
        end

        context 'when there are multiple reports' do
          let!(:sast_artifact) { create(:ee_ci_job_artifact, :sast, job: job, project: job.project) }
          let!(:ds_artifact) { create(:ee_ci_job_artifact, :dependency_scanning, job: job, project: job.project) }
          let!(:cs_artifact) { create(:ee_ci_job_artifact, :container_scanning, job: job, project: job.project) }
          let!(:dast_artifact) { create(:ee_ci_job_artifact, :dast, job: job, project: job.project) }

          it 'parses blobs and adds the results to the reports' do
            subject

            expect(security_reports.get_report('sast', sast_artifact).findings.size).to eq(5)
            expect(security_reports.get_report('dependency_scanning', ds_artifact).findings.size).to eq(4)
            expect(security_reports.get_report('container_scanning', cs_artifact).findings.size).to eq(8)
            expect(security_reports.get_report('dast', dast_artifact).findings.size).to eq(20)
          end
        end

        context 'when there is a corrupted sast report' do
          let!(:artifact) { create(:ee_ci_job_artifact, :sast_with_corrupted_data, job: job, project: job.project) }

          it 'stores an error' do
            subject

            expect(security_reports.get_report('sast', artifact)).to be_errored
          end
        end

        describe 'vulnerability_finding_signatures' do
          let!(:artifact) { create(:ee_ci_job_artifact, :sast, job: job, project: job.project) }

          where(signatures_enabled: [true, false])
          with_them do
            it 'parses the report' do
              stub_licensed_features(
                sast: true,
                vulnerability_finding_signatures: signatures_enabled
              )

              expect(::Gitlab::Ci::Parsers::Security::Sast).to receive(:new).with(
                artifact.file.read,
                kind_of(::Gitlab::Ci::Reports::Security::Report),
                signatures_enabled: signatures_enabled
              )

              subject
            end
          end
        end
      end

      context 'when there is unsupported file type' do
        let!(:artifact) { create(:ee_ci_job_artifact, :codequality, job: job, project: job.project) }

        before do
          allow(Enums::Ci::JobArtifact).to receive(:security_report_file_types).and_return(%w[codequality])
        end

        it 'stores an error' do
          subject

          expect(security_reports.get_report('codequality', artifact)).to be_errored
        end
      end
    end
  end

  describe '#collect_metrics_reports!' do
    subject { job.collect_metrics_reports!(metrics_report) }

    let(:metrics_report) { Gitlab::Ci::Reports::Metrics::Report.new }

    context 'when there is a metrics report' do
      before do
        create(:ee_ci_job_artifact, :metrics, job: job, project: job.project)
      end

      context 'when license has metrics_reports' do
        before do
          stub_licensed_features(metrics_reports: true)
        end

        it 'parses blobs and add the results to the report' do
          expect { subject }.to change { metrics_report.metrics.count }.from(0).to(2)
        end
      end

      context 'when license does not have metrics_reports' do
        before do
          stub_licensed_features(license_scanning: false)
        end

        it 'does not parse metrics report' do
          subject

          expect(metrics_report.metrics.count).to eq(0)
        end
      end
    end
  end

  describe '#collect_requirements_reports!' do
    subject { job.collect_requirements_reports!(requirements_report) }

    let(:requirements_report) { Gitlab::Ci::Reports::RequirementsManagement::Report.new }

    context 'when there is a requirements report' do
      before do
        create(:ee_ci_job_artifact, :all_passing_requirements_v2, job: job, project: job.project)
      end

      context 'when requirements are available' do
        before do
          stub_licensed_features(requirements: true)
        end

        it 'parses blobs and adds the results to the report' do
          expect { subject }.to change { requirements_report.requirements.count }.from(0).to(1)
          expect(requirements_report.requirements).to eq({ "*" => "passed" })
        end
      end

      context 'when requirements are not available' do
        before do
          stub_licensed_features(requirements: false)
        end

        it 'does not parse requirements report' do
          subject

          expect(requirements_report.requirements.count).to eq(0)
        end
      end
    end

    context 'when using legacy format' do
      subject { job.collect_requirements_reports!(requirements_report, legacy: true) }

      context 'when there is a requirements report' do
        before do
          create(:ee_ci_job_artifact, :all_passing_requirements, job: job, project: job.project)
        end

        context 'when requirements are available' do
          before do
            stub_licensed_features(requirements: true)
          end

          it 'parses blobs and adds the results to the report' do
            expect { subject }.to change { requirements_report.requirements.count }.from(0).to(1)
          end
        end

        context 'when requirements are not available' do
          before do
            stub_licensed_features(requirements: false)
          end

          it 'does not parse requirements report' do
            subject

            expect(requirements_report.requirements.count).to eq(0)
          end
        end
      end
    end
  end

  describe '#collect_sbom_reports!' do
    subject { job.collect_sbom_reports!(sbom_reports_list) }

    let(:sbom_reports_list) { Gitlab::Ci::Reports::Sbom::Reports.new }

    context 'when there is an sbom report' do
      let!(:cyclonedx_artifact) { create(:ee_ci_job_artifact, :cyclonedx, job: job, project: job.project) }

      it 'adds each report to the reports list and parses it' do
        subject

        aggregate_failures do
          expect(sbom_reports_list.reports.count).to eq(4)
          expect(sbom_reports_list.reports[0].components.count).to eq(46)
          expect(sbom_reports_list.reports[1].components.count).to eq(15)
          expect(sbom_reports_list.reports[2].components.count).to eq(28)
          expect(sbom_reports_list.reports[3].components.count).to eq(352)
        end
      end
    end
  end

  describe '#retryable?' do
    subject { build.retryable? }

    let(:pipeline) { merge_request.all_pipelines.last }
    let!(:build) { create(:ee_ci_build, :canceled, pipeline: pipeline) }

    context 'with pipeline for merged results' do
      let(:merge_request) { create(:merge_request, :with_merge_request_pipeline) }

      it { is_expected.to be true }
    end
  end

  describe ".license_scan" do
    it 'returns only license artifacts' do
      create(:ee_ci_build, job_artifacts: [create(:ci_job_artifact, :zip)])
      build_with_license_scan = create(:ee_ci_build, job_artifacts: [create(:ci_job_artifact, file_type: :license_scanning, file_format: :raw)])

      expect(described_class.license_scan).to contain_exactly(build_with_license_scan)
    end
  end

  describe ".sbom_generation" do
    it 'returns only cyclonedx sbom artifacts' do
      create(:ee_ci_build, job_artifacts: [create(:ci_job_artifact, :zip)])
      build_with_cyclonedx_sbom = create(:ee_ci_build, job_artifacts: [create(:ee_ci_job_artifact, :cyclonedx)])

      expect(described_class.sbom_generation).to contain_exactly(build_with_cyclonedx_sbom)
    end
  end

  describe '.recently_failed_on_instance_runner', :clean_gitlab_redis_shared_state, feature_category: :fleet_visibility do
    subject(:recently_failed_on_instance_runner) do
      described_class.recently_failed_on_instance_runner(failure_reason)
    end

    before do
      stub_licensed_features(runner_performance_insights: true)
    end

    let_it_be(:instance_runner) { create(:ci_runner, :instance) }
    let_it_be(:job_args) { { runner: instance_runner, failure_reason: :runner_system_failure } }
    let_it_be(:job1) { create(:ee_ci_build, :failed, finished_at: 1.minute.ago, **job_args) }
    let_it_be(:job2) { create(:ee_ci_build, :failed, finished_at: 2.minutes.ago, **job_args) }

    context 'with failure_reason set to :runner_system_failure' do
      let(:failure_reason) { :runner_system_failure }

      it 'returns no builds' do
        is_expected.to be_empty
      end

      context 'with 2 jobs tracked' do
        before do
          ::Ci::InstanceRunnerFailedJobs.track(job2)
          ::Ci::InstanceRunnerFailedJobs.track(job1)
        end

        it 'returns builds tracked by InstanceRunnerFailedJobs' do
          is_expected.to match([
            an_object_having_attributes(id: job1.id),
            an_object_having_attributes(id: job2.id)
          ])
        end

        it 'overrides the order of returned builds' do
          expect(described_class.order(id: :asc).recently_failed_on_instance_runner(failure_reason)).to match([
            an_object_having_attributes(id: job1.id),
            an_object_having_attributes(id: job2.id)
          ])

          expect(described_class.order(id: :desc).recently_failed_on_instance_runner(failure_reason)).to match([
            an_object_having_attributes(id: job1.id),
            an_object_having_attributes(id: job2.id)
          ])
        end
      end
    end
  end

  describe 'ci_secrets_management_available?' do
    subject { job.ci_secrets_management_available? }

    context 'when secrets management feature is available' do
      before do
        stub_licensed_features(ci_secrets_management: true)
      end

      it { is_expected.to be true }
    end

    context 'when secrets management feature is not available' do
      before do
        stub_licensed_features(ci_secrets_management: false)
      end

      it { is_expected.to be false }
    end
  end

  describe '#features' do
    subject(:features) { job.features }

    let(:otel_endpoint) { 'https://otel-collector.example.com/v1/traces' }

    before do
      stub_application_setting(ci_telemetry_otel_endpoint: otel_endpoint)
      stub_application_setting(ci_job_telemetry_sampling_rate: 1.0)
    end

    def job_running_span_id_for(build)
      Gitlab::Ci::JobTelemetry::SpanEmitter
        .new(build)
        .span_id_for(Gitlab::Ci::JobTelemetry::SpanEmitter::SPAN_KIND_RUNNING)
    end

    it 'includes tracing with trace_id, span_parent_id (job_running span), and otel_endpoints' do
      expect(features[:tracing]).to eq(
        trace_id: format('%032x', pipeline.id),
        span_parent_id: job_running_span_id_for(job),
        otel_endpoints: [{ url: otel_endpoint }]
      )
    end

    context 'when job belongs to a child pipeline' do
      let_it_be(:bridge) { create(:ci_bridge, pipeline: pipeline) }
      let_it_be(:child_pipeline) { create(:ci_pipeline, source: :parent_pipeline, project: project) }
      let_it_be(:source_pipeline) do
        create(:ci_sources_pipeline, source_job: bridge, source_project: project,
          pipeline: child_pipeline, project: project)
      end

      let_it_be_with_refind(:child_job) { create(:ee_ci_build, pipeline: child_pipeline) }

      let(:job) { child_job }

      it 'includes tracing with trace_id from root pipeline and span_parent_id from job_running span' do
        expect(features[:tracing]).to eq(
          trace_id: format('%032x', pipeline.id),
          span_parent_id: job_running_span_id_for(child_job),
          otel_endpoints: [{ url: otel_endpoint }]
        )
      end
    end

    context 'when job belongs to a dangling child pipeline without source bridge' do
      let_it_be(:child_pipeline) { create(:ci_pipeline, source: :parent_pipeline, project: project) }
      let_it_be_with_refind(:child_job) { create(:ee_ci_build, pipeline: child_pipeline) }

      let(:job) { child_job }

      it 'includes tracing with span_parent_id from job_running span' do
        expect(features[:tracing]).to eq(
          trace_id: format('%032x', child_pipeline.id),
          span_parent_id: job_running_span_id_for(child_job),
          otel_endpoints: [{ url: otel_endpoint }]
        )
      end
    end

    context 'when ci_job_telemetry feature flag is disabled' do
      before do
        stub_feature_flags(ci_job_telemetry: false)
      end

      it { is_expected.not_to have_key(:tracing) }
    end

    context 'when ci_telemetry_otel_endpoint is not configured' do
      before do
        stub_application_setting(ci_telemetry_otel_endpoint: nil)
      end

      it { is_expected.not_to have_key(:tracing) }
    end

    context 'when ci_telemetry_otel_endpoint is blank' do
      before do
        stub_application_setting(ci_telemetry_otel_endpoint: '')
      end

      it { is_expected.not_to have_key(:tracing) }
    end

    context 'when ci_job_telemetry_sampling_rate is 0.0' do
      before do
        stub_application_setting(ci_job_telemetry_sampling_rate: 0.0)
      end

      it { is_expected.not_to have_key(:tracing) }
    end

    context 'when ci_job_telemetry_sampling_rate is 1.0' do
      before do
        stub_application_setting(ci_job_telemetry_sampling_rate: 1.0)
      end

      it 'includes tracing' do
        expect(features[:tracing]).to be_present
      end
    end

    context 'when ci_job_telemetry_sampling_rate is between 0.0 and 1.0' do
      let(:sampling_bucket_count) { EE::Ci::Build::TELEMETRY_SAMPLING_BUCKET_COUNT }
      let(:bucket) { OpenSSL::Digest::SHA256.hexdigest(pipeline.id.to_s).to_i(16) % sampling_bucket_count }

      context 'when pipeline hashes below the threshold' do
        before do
          stub_application_setting(ci_job_telemetry_sampling_rate: (bucket + 1).to_f / sampling_bucket_count)
        end

        it 'includes tracing' do
          expect(features[:tracing]).to be_present
        end
      end

      context 'when pipeline hashes at or above the threshold' do
        before do
          stub_application_setting(ci_job_telemetry_sampling_rate: bucket.to_f / sampling_bucket_count)
        end

        it { is_expected.not_to have_key(:tracing) }
      end

      context 'when root pipeline ID is not available' do
        before do
          stub_application_setting(ci_job_telemetry_sampling_rate: 0.5)
          allow(job).to receive(:pipeline).and_return(nil)
        end

        it { is_expected.not_to have_key(:tracing) }
      end
    end

    context 'when job is not persisted' do
      let(:job) { build(:ee_ci_build) }

      it { is_expected.not_to have_key(:tracing) }
    end
  end

  describe 'job telemetry span emission', feature_category: :fleet_visibility do
    let(:emitter) do
      instance_double(
        Gitlab::Ci::JobTelemetry::SpanEmitter,
        emit_job_pending: nil,
        emit_job_running: nil,
        emit_job_lifecycle: nil,
        span_id_for: 'abcdefgh12345678'
      )
    end

    before do
      stub_application_setting(ci_telemetry_otel_endpoint: 'https://otel.example.com', ci_job_telemetry_sampling_rate: 1.0)
      allow(Gitlab::Ci::JobTelemetry::Tracer.instance).to receive(:enabled?).and_return(true)
      allow(Gitlab::Ci::JobTelemetry::SpanEmitter).to receive(:new).and_return(emitter)
    end

    describe 'guards' do
      where(:scenario, :stub) do
        'feature flag disabled' | -> { stub_feature_flags(ci_job_telemetry: false) }
        'sampling rate is 0'    | -> { stub_application_setting(ci_job_telemetry_sampling_rate: 0.0) }
        'tracer is disabled'    | -> { allow(Gitlab::Ci::JobTelemetry::Tracer.instance).to receive(:enabled?).and_return(false) }
      end

      with_them do
        before do
          instance_exec(&stub)
        end

        it 'skips pending span emission' do
          job.emit_telemetry_pending_span

          expect(emitter).not_to have_received(:emit_job_pending)
        end

        it 'skips lifecycle span emission' do
          job.emit_telemetry_lifecycle_spans

          expect(emitter).not_to have_received(:emit_job_running)
          expect(emitter).not_to have_received(:emit_job_lifecycle)
        end
      end
    end

    describe '#emit_telemetry_pending_span' do
      it 'emits the job_pending span' do
        job.emit_telemetry_pending_span

        expect(emitter).to have_received(:emit_job_pending)
      end
    end

    describe '#emit_telemetry_lifecycle_spans' do
      subject(:emit_telemetry_lifecycle_spans) { job.emit_telemetry_lifecycle_spans }

      context 'when the job ran (started_at is present)' do
        let(:job) { build_stubbed(:ee_ci_build, :success, pipeline: pipeline, started_at: 1.minute.ago) }

        it 'emits both job_running and job_lifecycle spans' do
          emit_telemetry_lifecycle_spans

          expect(emitter).to have_received(:emit_job_running)
          expect(emitter).to have_received(:emit_job_lifecycle).with(status: 'success')
        end
      end

      context 'when the job never ran (no started_at)' do
        let(:job) { build_stubbed(:ee_ci_build, :canceled, pipeline: pipeline, started_at: nil) }

        it 'emits only the job_lifecycle span' do
          emit_telemetry_lifecycle_spans

          expect(emitter).not_to have_received(:emit_job_running)
          expect(emitter).to have_received(:emit_job_lifecycle).with(status: 'canceled')
        end
      end
    end

    describe 'state machine transitions' do
      let(:job) { create(:ee_ci_build, :pending, :queued, pipeline: pipeline) }

      it 'emits job_pending span on pending -> running transition' do
        job.run!

        expect(emitter).to have_received(:emit_job_pending)
      end

      where(:transition_method, :expected_status) do
        :success! | 'success'
        :drop!    | 'failed'
        :cancel!  | 'canceled'
      end

      with_them do
        it 'emits lifecycle spans with the correct status' do
          job.run!
          job.public_send(transition_method)

          expect(emitter).to have_received(:emit_job_lifecycle).with(status: expected_status)
        end
      end
    end
  end

  describe '#runner_required_feature_names' do
    let(:build) { create(:ee_ci_build, secrets: secrets) }

    subject { build.runner_required_feature_names }

    context 'when secrets management feature is available' do
      before do
        stub_licensed_features(ci_secrets_management: true)
      end

      context 'when there are secrets defined' do
        let(:secrets) { valid_secrets }

        it { is_expected.to include(:vault_secrets) }
      end

      context 'when there are no secrets defined' do
        let(:secrets) { {} }

        it { is_expected.not_to include(:vault_secrets) }
      end
    end

    context 'when secrets management feature is not available' do
      before do
        stub_licensed_features(ci_secrets_management: false)
      end

      context 'when there are secrets defined' do
        let(:secrets) { valid_secrets }

        it { is_expected.not_to include(:vault_secrets) }
      end

      context 'when there are no secrets defined' do
        let(:secrets) { {} }

        it { is_expected.not_to include(:vault_secrets) }
      end
    end
  end

  describe 'secrets management usage data' do
    before do
      allow(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event).and_call_original
    end

    let_it_be(:user) { create(:user) }

    let_it_be(:valid_secret_configs) do
      {
        vault: {
          PASSWORD_1: {
            vault: {
              engine: { name: 'kv-v2', path: 'kv-v2' },
              path: 'production/db',
              field: 'password'
            }
          }
        },
        gcp_secret_manager: {
          PASSWORD_2: {
            gcp_secret_manager: {
              name: 'my-secret'
            },
            token: '$ID_TOKEN'
          }
        },
        azure_key_vault: {
          PASSWORD_3: {
            azure_key_vault: {
              name: 'my-secret'
            }
          }
        },
        aws_secrets_manager: {
          PASSWORD_4: {
            aws_secrets_manager: {
              secret_id: 'my-secret'
            }
          }
        }
      }
    end

    shared_examples 'not tracking usage for provider' do |provider:|
      it 'does not track RedisHLL event' do
        expect(::Gitlab::UsageDataCounters::HLLRedisCounter).not_to receive(:track_event).with("i_ci_secrets_management_#{provider}_build_created")

        ci_build.save!
      end

      it 'does not track Snowplow event' do
        ci_build.save!

        expect_no_snowplow_event(category: described_class.to_s, action: "create_secrets_#{provider}")
      end
    end

    shared_examples 'tracking usage for provider' do |provider:|
      it 'tracks RedisHLL event with user_id' do
        expect(::Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
          .with("i_ci_secrets_management_#{provider}_build_created", values: user.id)

        ci_build.save!
      end

      it 'tracks Snowplow event with RedisHLL context' do
        params = {
          category: described_class.to_s,
          action: "create_secrets_#{provider}",
          namespace: ci_build.namespace,
          user: user,
          label: "redis_hll_counters.ci_secrets_management.i_ci_secrets_management_#{provider}_build_created_monthly",
          ultimate_namespace_id: ci_build.namespace.root_ancestor.id,
          context: [::Gitlab::Tracking::ServicePingContext.new(
            data_source: :redis_hll,
            event: "i_ci_secrets_management_#{provider}_build_created"
          ).to_context.to_json]
        }

        ci_build.save!

        expect_snowplow_event(**params)
      end

      it 'does not track unused providers' do
        unused_providers = Gitlab::Ci::Config::Entry::Secret::SUPPORTED_PROVIDERS - [provider]
        unused_providers.each do |unused_provider|
          expect(::Gitlab::UsageDataCounters::HLLRedisCounter).not_to receive(:track_event).with("i_ci_secrets_management_#{unused_provider}_build_created")
        end

        ci_build.save!

        unused_providers.each do |unused_provider|
          expect_no_snowplow_event(category: described_class.to_s, action: "create_secrets_#{unused_provider}")
        end
      end
    end

    context 'when secrets management feature is not available' do
      before do
        stub_licensed_features(ci_secrets_management: false)
      end

      (Gitlab::Ci::Config::Entry::Secret::SUPPORTED_PROVIDERS - [:gitlab_secrets_manager]).each do |provider|
        context "when using #{provider}" do
          let(:valid_secret) { valid_secret_configs.fetch(provider) }
          let(:ci_build) { build(:ee_ci_build, secrets: valid_secret, ci_stage: stage) }

          it_behaves_like 'not tracking usage for provider', provider: provider
        end
      end
    end

    context 'when secrets management feature is available' do
      before do
        stub_licensed_features(ci_secrets_management: true)
      end

      context 'when there are secrets defined' do
        (Gitlab::Ci::Config::Entry::Secret::SUPPORTED_PROVIDERS - [:gitlab_secrets_manager]).each do |provider|
          context "when using #{provider}" do
            let(:valid_secret) { valid_secret_configs.fetch(provider) }

            context 'on create' do
              let(:ci_build) { build(:ee_ci_build, secrets: valid_secret, user: user, ci_stage: stage) }

              it_behaves_like 'tracking usage for provider', provider: provider
            end

            context 'on update' do
              let(:ci_build) { create(:ee_ci_build, secrets: valid_secret, user: user) }

              before do
                ci_build.success
              end

              it_behaves_like 'not tracking usage for provider', provider: provider
            end
          end
        end

        context 'when using multiple providers' do
          let(:valid_secret) { valid_secret_configs.values.inject(:merge) }

          let(:ci_build) { build(:ee_ci_build, secrets: valid_secret, user: user, ci_stage: stage) }
          let(:supported_providers_with_tracking) { Gitlab::Ci::Config::Entry::Secret::SUPPORTED_PROVIDERS - [:gitlab_secrets_manager] }

          it 'tracks RedisHLL event with user_id on all providers' do
            supported_providers_with_tracking.each do |provider|
              expect(::Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
                .with("i_ci_secrets_management_#{provider}_build_created", values: user.id)
            end

            ci_build.save!
          end

          it 'tracks Snowplow event with RedisHLL context on all providers' do
            ci_build.save!

            supported_providers_with_tracking.each do |provider|
              params = {
                category: described_class.to_s,
                action: "create_secrets_#{provider}",
                namespace: ci_build.namespace,
                user: user,
                label: "redis_hll_counters.ci_secrets_management.i_ci_secrets_management_#{provider}_build_created_monthly",
                ultimate_namespace_id: ci_build.namespace.root_ancestor.id,
                context: [::Gitlab::Tracking::ServicePingContext.new(
                  data_source: :redis_hll,
                  event: "i_ci_secrets_management_#{provider}_build_created"
                ).to_context.to_json]
              }

              expect_snowplow_event(**params)
            end
          end
        end

        context 'when using repeated providers' do
          let(:valid_secret) do
            {
              PASSWORD_1: {
                gcp_secret_manager: {
                  name: 'my-secret-1'
                },
                token: '$ID_TOKEN'
              },
              PASSWORD_2: {
                gcp_secret_manager: {
                  name: 'my-secret-2'
                },
                token: '$ID_TOKEN'
              }
            }
          end

          let(:ci_build) { build(:ee_ci_build, secrets: valid_secret, user: user, ci_stage: stage) }

          it 'tracks a single RedisHLL event with user_id on the provider' do
            expect(::Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
              .with('i_ci_secrets_management_gcp_secret_manager_build_created', values: user.id).once

            ci_build.save!
          end

          it 'tracks a single Snowplow event with RedisHLL context on all providers' do
            ci_build.save!

            params = {
              category: described_class.to_s,
              action: 'create_secrets_gcp_secret_manager',
              namespace: ci_build.namespace,
              user: user,
              label: 'redis_hll_counters.ci_secrets_management.i_ci_secrets_management_gcp_secret_manager_build_created_monthly',
              ultimate_namespace_id: ci_build.namespace.root_ancestor.id,
              context: [::Gitlab::Tracking::ServicePingContext.new(
                data_source: :redis_hll,
                event: 'i_ci_secrets_management_gcp_secret_manager_build_created'
              ).to_context.to_json]
            }

            expect_snowplow_event(**params)
          end
        end
      end
    end

    context 'when there are no secrets defined' do
      let(:ci_build) { build(:ee_ci_build, user: user, ci_stage: stage) }

      context 'on create' do
        Gitlab::Ci::Config::Entry::Secret::SUPPORTED_PROVIDERS.each do |provider|
          it_behaves_like 'not tracking usage for provider', provider: provider
        end
      end
    end
  end

  describe '#secrets_integration' do
    it 'instantiates ::Ci::Secrets::Integration only with variables of the build related to secrets integration' do
      expect(job).not_to receive(:job_jwt_variables)
      expect(job).not_to receive(:variables)
      expect(job).to receive(:scoped_variables).and_call_original
      expect(job).to receive(:job_variables).and_call_original

      expect(job.secrets_integration).to be_a(::Ci::Secrets::Integration)
    end
  end

  describe '#secrets_provider?' do
    it 'delegates to secrets_integration' do
      expect(job).to delegate_method(:secrets_provider?).to(:secrets_integration)
    end
  end

  describe 'build identity' do
    let_it_be(:user) { create(:user) }

    let(:identity) { 'google_cloud' }
    let(:build) do
      create(:ee_ci_build, pipeline: pipeline, user: user, options: { identity: identity })
    end

    subject(:variables) { build.variables }

    before do
      rsa_key = OpenSSL::PKey::RSA.generate(3072)
      stub_application_setting(ci_jwt_signing_key: rsa_key.to_s)
    end

    it 'does not include the gcloud file variables' do
      runner_vars = variables.to_runner_variables.index_by { |v| v[:key] }
      runner_var_names = runner_vars.keys

      expect(runner_var_names).not_to include('CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE')
      expect(runner_var_names).not_to include('GOOGLE_APPLICATION_CREDENTIALS')
    end

    context 'with integration active' do
      let_it_be(:project) { create(:project) }
      let_it_be(:integration) { create(:google_cloud_platform_workload_identity_federation_integration, project: project) }
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, status: 'success') }

      it 'includes the gcloud file variables' do
        runner_vars = variables.to_runner_variables.index_by { |v| v[:key] }
        runner_var_names = runner_vars.keys

        expect(runner_var_names).to include('CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE')
        expect(runner_var_names).to include('GOOGLE_APPLICATION_CREDENTIALS')
        expect(runner_vars['GOOGLE_APPLICATION_CREDENTIALS']).to include(file: true)
        expect(runner_vars['GOOGLE_APPLICATION_CREDENTIALS'].except(:key)).to eq(
          runner_vars['CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE'].except(:key))

        json = Gitlab::Json.parse(runner_vars['CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE'][:value])
        expect(json).to match(
          'type' => 'external_account',
          'audience' => an_instance_of(String),
          'subject_token_type' => 'urn:ietf:params:oauth:token-type:jwt',
          'token_url' => 'https://sts.googleapis.com/v1/token',
          'credential_source' => {
            'url' => 'https://auth.gcp.gitlab.com/token',
            'headers' => { 'Authorization' => an_instance_of(String) },
            'format' => { 'type' => 'json', 'subject_token_field_name' => 'token' }
          })
      end

      context 'when identity is unknown' do
        let(:identity) { 'unknown' }

        it 'raises an error' do
          expect { subject }.to raise_error ArgumentError, "Unknown identity value: #{identity}"
        end
      end
    end
  end

  context 'with loose foreign keys for partitioned tables' do
    before do
      create(:security_scan, build: job)
    end

    it 'removes records through partitioned LFK' do
      pipeline.destroy!

      expect do
        LooseForeignKeys::ProcessDeletedRecordsService.new(
          connection: job.connection,
          worker_class: LooseForeignKeys::CiPipelinesBuildsCleanupCronWorker
        ).execute
      end.to change { Security::Scan.count }.by(-1)
    end
  end

  describe '#pages', feature_category: :pages do
    where(:pages_generator, :options, :result) do
      false | {} | {}
      false | { pages: { path_prefix: 'foo' } } | {}
      true | { pages: { path_prefix: 'foo' } } | { path_prefix: 'foo' }
      true | { pages: { path_prefix: nil } } | {}
      true | { pages: { path_prefix: 'foo' }, publish: 'public' } | { path_prefix: 'foo', publish: 'public' }
      true | { pages: { path_prefix: 'foo', publish: 'public' } } | { path_prefix: 'foo', publish: 'public' }
      true | { pages: { path_prefix: '$CI_COMMIT_BRANCH' } } | { path_prefix: 'master' }
      true | { pages: { path_prefix: 'foo', expire_in: '1d' } } | { path_prefix: 'foo', expire_in: '1d' }
      true | { pages: { path_prefix: 'foo', expire_in: '1d', publish: '$CUSTOM_FOLDER' } } | { path_prefix: 'foo', expire_in: '1d', publish: 'custom_folder' }
      true | { pages: { path_prefix: 'foo', expire_in: '1d', publish: 'public' } } | { path_prefix: 'foo', expire_in: '1d', publish: 'public' }
      true | { pages: { path_prefix: 'foo', expire_in: '$DURATION', publish: '$CUSTOM_FOLDER' } } | { path_prefix: 'foo', expire_in: '2d', publish: 'custom_folder' }
      true | { pages: { path_prefix: 'foo', expire_in: 'never' } } | { path_prefix: 'foo', expire_in: 'never' }
    end

    with_them do
      before do
        allow(job).to receive(:pages_generator?).and_return(pages_generator)
        stub_ci_job_definition(job, options: options)
        create(:ci_job_variable, key: 'CUSTOM_FOLDER', value: 'custom_folder', job: job)
        create(:ci_job_variable, key: 'DURATION', value: '2d', job: job)
      end

      subject(:pages_options) { job.pages }

      it { is_expected.to eq(result) }
    end
  end

  describe 'google artifact registry integration' do
    subject(:variables) { job.variables.to_runner_variables }

    shared_examples 'does not include environment variables' do
      it 'does not include environment variables', :aggregate_failures do
        var_names = subject.pluck(:key)

        %w[
          GOOGLE_ARTIFACT_REGISTRY_PROJECT_ID
          GOOGLE_ARTIFACT_REGISTRY_REPOSITORY_NAME
          GOOGLE_ARTIFACT_REGISTRY_REPOSITORY_LOCATION
        ].each do |var_name|
          expect(var_names).not_to include(var_name)
        end
      end
    end

    it_behaves_like "does not include environment variables"

    context 'with saas only enabled' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      it_behaves_like "does not include environment variables"

      context 'with integration active' do
        let_it_be(:integration) { create(:google_cloud_platform_artifact_registry_integration) }
        let_it_be(:pipeline) { create(:ci_pipeline, project: integration.project, status: 'success') }

        it 'includes the environment variables', :aggregate_failures do
          {
            'GOOGLE_ARTIFACT_REGISTRY_PROJECT_ID' => integration.artifact_registry_project_id,
            'GOOGLE_ARTIFACT_REGISTRY_REPOSITORY_NAME' => integration.artifact_registry_repository,
            'GOOGLE_ARTIFACT_REGISTRY_REPOSITORY_LOCATION' => integration.artifact_registry_location
          }.each do |var_name, var_value|
            expect(subject).to include({
              key: var_name,
              value: var_value,
              public: true,
              masked: false
            })
          end
        end
      end
    end
  end

  describe "license management metrics" do
    let_it_be(:user) { create(:user) }
    let_it_be(:test_pipeline) { create(:ci_pipeline, project: project, ref: 'master', user: user) }
    let_it_be(:stage) { create(:ci_stage, pipeline: test_pipeline, project: project) }

    let(:metrics) do
      [
        'counts.count_total_license_management_ci_builds_weekly',
        'counts.count_total_license_management_ci_builds_monthly'
      ]
    end

    let(:command) do
      Gitlab::Ci::Pipeline::Chain::Command.new(
        project: project,
        current_user: user,
        origin_ref: 'master'
      )
    end

    let(:step) { Gitlab::Ci::Pipeline::Chain::Metrics.new(test_pipeline, command) }

    subject(:run_metrics_chain) { step.perform! }

    context "with license_scanning ci build" do
      let(:name) { 'license_scanning' }

      let_it_be(:build) do
        create(:ee_ci_build, pipeline: test_pipeline, ci_stage: stage, project: project, name: 'license_scanning', user: user)
      end

      before do
        test_pipeline.builds.reload
      end

      it "enqueues PipelineCreationMetricsWorker" do
        expect(Ci::PipelineCreationMetricsWorker)
          .to receive(:perform_async).with(test_pipeline.id, nil, anything, anything)

        run_metrics_chain
      end
    end

    context "with a different build name" do
      let_it_be(:other_build) do
        create(:ee_ci_build, pipeline: test_pipeline, ci_stage: stage, project: project, name: 'test123', user: user)
      end

      before do
        test_pipeline.builds.reload
      end

      it "enqueues PipelineCreationMetricsWorker" do
        expect(Ci::PipelineCreationMetricsWorker)
          .to receive(:perform_async).with(test_pipeline.id, nil, anything, anything)

        run_metrics_chain
      end
    end
  end

  describe 'JobSecurityScanCompletedEvent publishing' do
    let(:build) { create(:ee_ci_build, :running, pipeline: pipeline) }

    context 'when build is a security job' do
      before do
        allow(build).to receive(:security_job?).and_return(true)
      end

      context "when actions aren't complete statuses" do
        where(:transition_method, :transition_description) do
          [
            [:process, 'created'],
            [:enqueue, 'pending'],
            [:run, 'running']
          ]
        end

        with_them do
          context "when transitioning to #{params[:transition_description]}" do
            it 'does not publish the JobSecurityScanCompletedEvent' do
              expect(::Gitlab::EventStore).not_to receive(:publish)

              build.public_send(transition_method)
            end
          end
        end
      end

      context "when actions are complete statuses" do
        where(:transition_method, :transition_description) do
          [
            [:success, 'success'],
            [:drop, 'failed'],
            [:cancel, 'canceled']
          ]
        end

        with_them do
          context "when transitioning to #{params[:transition_description]}" do
            it 'publishes JobSecurityScanCompletedEvent' do
              expect(::Gitlab::EventStore).to receive(:publish) do |event|
                expect(event).to be_an_instance_of(::Ci::JobSecurityScanCompletedEvent)
                expect(event.data).to eq({ "job_id" => build.id })
              end
              build.public_send(transition_method)
            end
          end
        end
      end
    end

    context 'when build is not a security job' do
      before do
        allow(build).to receive(:security_job?).and_return(false)
      end

      where(:transition_method, :transition_description) do
        [
          [:success, 'success'],
          [:drop, 'failed'],
          [:cancel, 'canceled']
        ]
      end

      with_them do
        context "when transitioning to #{params[:transition_description]}" do
          it 'does not publish the JobSecurityScanCompletedEvent' do
            expect(::Gitlab::EventStore).not_to receive(:publish)

            build.public_send(transition_method)
          end
        end
      end
    end
  end
end
