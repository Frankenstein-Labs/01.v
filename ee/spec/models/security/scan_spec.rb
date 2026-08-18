# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Scan, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  it_behaves_like 'cleanup by a loose foreign key' do
    let!(:model) { create(:security_scan) }
    let(:parent) { model.build }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:build) }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:pipeline) }
    it { is_expected.to have_many(:findings) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:build_id) }
    it { is_expected.to validate_presence_of(:scan_type) }

    describe 'info' do
      let(:scan) { build(:security_scan, info: info) }

      subject { scan.errors.details[:info] }

      before do
        scan.validate
      end

      context 'when the value for info field is valid' do
        let(:info) { { errors: [{ type: 'Foo', message: 'Message' }] } }

        it { is_expected.to be_empty }
      end

      context 'when the value for info field is invalid' do
        let(:info) { { errors: [{ type: 'Foo' }] } }

        it { is_expected.not_to be_empty }
      end
    end
  end

  describe '#name' do
    it { is_expected.to delegate_method(:name).to(:build) }
  end

  describe '#findings_can_be_purged?' do
    let(:scan) { create(:security_scan, created_at: created_at, status: status) }

    subject { scan.findings_can_be_purged? }

    context 'when the record is created in less than 3 months ago' do
      let(:created_at) { 2.months.ago }

      context 'when the record is not purged' do
        let(:status) { :succeeded }

        it { is_expected.to be_falsey }
      end

      context 'when the record is purged' do
        let(:status) { :purged }

        it { is_expected.to be_falsey }
      end
    end

    context 'when the record is created in more than 3 months ago' do
      let(:created_at) { 4.months.ago }

      context 'when the record is not purged' do
        let(:status) { :succeeded }

        it { is_expected.to be_falsey }
      end

      context 'when the record is purged' do
        let(:status) { :purged }

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#has_warnings?' do
    let(:scan) { build(:security_scan, info: info) }

    subject { scan.has_warnings? }

    context 'when the info attribute is nil' do
      let(:info) { nil }

      it 'is not valid' do
        expect(scan.valid?).to be(false)
      end
    end

    context 'when the info attribute is present' do
      let(:info) { { warnings: warnings } }

      context 'when there is no warnings' do
        let(:warnings) { [] }

        it { is_expected.to be(false) }
      end

      context 'when there are warnings' do
        let(:warnings) { [{ type: 'Foo', message: 'Bar' }] }

        it { is_expected.to be(true) }
      end
    end
  end

  describe '#processing_warnings' do
    let(:scan) { build(:security_scan, info: info) }
    let(:info) { { warnings: validator_warnings } }

    subject(:warnings) { scan.processing_warnings }

    context 'when there are warnings' do
      let(:validator_warnings) { [{ type: 'Foo', message: 'Bar' }] }

      it 'returns all warnings' do
        expect(warnings).to match_array([{ "message" => "Bar", "type" => "Foo" }])
      end
    end

    context 'when there are no warnings' do
      let(:validator_warnings) { [] }

      it 'returns []' do
        expect(warnings).to match_array(validator_warnings)
      end
    end
  end

  describe '#processing_warnings=' do
    let(:scan) { create(:security_scan) }

    subject(:set_warnings) { scan.processing_warnings = [:foo] }

    it 'sets the warnings' do
      expect { set_warnings }.to change { scan.info['warnings'] }.from(nil).to([:foo])
    end
  end

  describe '#has_warnings?' do
    let(:scan) { build(:security_scan, info: info) }
    let(:info) { { warnings: validator_warnings } }

    subject(:has_warnings?) { scan.has_warnings? }

    context 'when there are warnings' do
      let(:validator_warnings) { [{ type: 'Foo', message: 'Bar' }] }

      it 'returns true' do
        expect(has_warnings?).to be(true)
      end
    end

    context 'when there are no warnings' do
      let(:validator_warnings) { [] }

      it 'returns false' do
        expect(has_warnings?).to be(false)
      end
    end
  end

  describe '#has_errors?' do
    let(:scan) { build(:security_scan, info: info) }

    subject { scan.has_errors? }

    context 'when the info attribute is nil' do
      let(:info) { nil }

      it 'is not valid' do
        expect(scan.valid?).to be(false)
      end
    end

    context 'when the info attribute presents' do
      let(:info) { { errors: errors } }

      context 'when there is no error' do
        let(:errors) { [] }

        it { is_expected.to be(false) }
      end

      context 'when there are errors' do
        let(:errors) { [{ type: 'Foo', message: 'Bar' }] }

        it { is_expected.to be(true) }
      end
    end
  end

  describe '.by_scan_types' do
    let_it_be(:sast_scan) { create(:security_scan, scan_type: :sast) }
    let_it_be(:dast_scan) { create(:security_scan, scan_type: :dast) }

    let(:expected_scans) { [sast_scan] }

    subject { described_class.by_scan_types(:sast) }

    it { is_expected.to match_array(expected_scans) }

    context 'when an invalid enum value is given' do
      subject { described_class.by_scan_types([:sast, :generic]) }

      it { is_expected.to match_array(expected_scans) }
    end
  end

  describe '.by_project' do
    let_it_be(:project) { create(:project) }
    let_it_be(:other_project) { create(:project) }

    let_it_be(:sast_scan) { create(:security_scan, scan_type: :sast, project: project) }
    let_it_be(:dast_scan) { create(:security_scan, scan_type: :dast, project: other_project) }

    let(:expected_scans) { [sast_scan] }

    subject { described_class.by_project(project) }

    it { is_expected.to match_array(expected_scans) }
  end

  describe '.distinct_scan_types' do
    let_it_be(:sast_scan) { create(:security_scan, scan_type: :sast) }
    let_it_be(:sast_scan2) { create(:security_scan, scan_type: :sast) }
    let_it_be(:dast_scan) { create(:security_scan, scan_type: :dast) }

    let(:expected_scans) { %w[sast dast] }

    subject { described_class.distinct_scan_types }

    it { is_expected.to match_array(expected_scans) }
  end

  describe '.latest_successful' do
    let_it_be(:first_successful_scan) { create(:security_scan, latest: false, status: :succeeded) }
    let_it_be(:second_successful_scan) { create(:security_scan, latest: true, status: :succeeded) }
    let_it_be(:failed_scan) { create(:security_scan, latest: true, status: :job_failed) }

    subject { described_class.latest_successful }

    it { is_expected.to match_array([second_successful_scan]) }
  end

  describe '.by_build_ids' do
    let_it_be(:sast_scan) { create(:security_scan, scan_type: :sast) }
    let_it_be(:dast_scan) { create(:security_scan, scan_type: :dast, build: sast_scan.build) }
    let(:expected_scans) { [sast_scan, dast_scan] }

    subject { described_class.by_build_ids(expected_scans.map(&:build_id)) }

    it { with_cross_joins_prevented { is_expected.to match_array(expected_scans) } }
  end

  describe '.by_pipeline_ids' do
    let_it_be(:pipeline_1) { create(:ee_ci_pipeline, :success) }
    let_it_be(:pipeline_2) { create(:ee_ci_pipeline, :success) }
    let_it_be(:scan_1) { create(:security_scan, pipeline: pipeline_1) }
    let_it_be(:scan_2) { create(:security_scan, pipeline: pipeline_2) }
    let_it_be(:unrelated_scan) { create(:security_scan) }

    subject { described_class.by_pipeline_ids([pipeline_1.id, pipeline_2.id]) }

    it { is_expected.to contain_exactly(scan_1, scan_2) }
  end

  describe '.without_statuses' do
    let_it_be(:succeeded_scan) { create(:security_scan, status: :succeeded) }
    let_it_be(:purged_scan) { create(:security_scan, status: :purged) }
    let_it_be(:preparing_scan) { create(:security_scan, status: :preparing) }

    subject { described_class.without_statuses(statuses) }

    context 'when given a list of statuses' do
      let(:statuses) { %i[purged preparing] }

      it { is_expected.to match_array([succeeded_scan]) }
    end

    context 'when given a single status' do
      let(:statuses) { :purged }

      it { is_expected.to match_array([succeeded_scan, preparing_scan]) }
    end

    context 'when given no statuses' do
      let(:statuses) { [] }

      it { is_expected.to match_array([succeeded_scan, purged_scan, preparing_scan]) }
    end
  end

  describe '#projects_with_scans' do
    let_it_be(:project_1) { create(:project) }
    let_it_be(:project_2) { create(:project) }
    let_it_be(:scan_1) { create(:security_scan, project: project_1) }
    let(:expected_scans) { [project_1.id] }

    subject { described_class.projects_with_scans([project_1.id, project_2.id]) }

    it { is_expected.to match_array(expected_scans) }
  end

  describe '.results_ready?' do
    let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

    subject(:results_ready?) { described_class.results_ready?(pipeline) }

    context 'when all security jobs are complete' do
      let_it_be(:sast_build) { create(:ee_ci_build, :sast, :success, pipeline: pipeline, project: project) }

      before do
        create(:ee_ci_build, :running, pipeline: pipeline, project: project)
      end

      # Scans are created after ci build commit
      it 'returns false when there are scans processing' do
        expect(results_ready?).to be(false)
      end

      context 'when there are no scans processing' do
        before do
          sast_build.security_scans.update_all(status: :succeeded)
        end

        it { is_expected.to be(true) }
      end

      context 'when a scan is preparing but not latest' do
        before do
          sast_build.security_scans.update_all(status: :preparing, latest: false)
        end

        it { is_expected.to be(true) }
      end
    end

    context 'when security jobs are still running' do
      before do
        create(:ee_ci_build, :sast, :running, pipeline: pipeline, project: project)
      end

      it { is_expected.to be(false) }
    end

    context 'when pipeline is blocked by manual jobs' do
      let_it_be(:pipeline) { create(:ci_pipeline, :blocked, project: project) }

      before do
        create(:ee_ci_build, :sast, :success, pipeline: pipeline, project: project)
        create(:ee_ci_build, :dast, :manual, :actionable, pipeline: pipeline, project: project)
      end

      it 'returns false when scans are still processing' do
        expect(results_ready?).to be(false)
      end

      context 'when scans are succeeded' do
        before do
          pipeline.security_scans.update_all(status: :succeeded)
        end

        it { is_expected.to be(true) }
      end
    end
  end

  describe '.processing?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be_with_reload(:pipeline) { create(:ci_pipeline, project: project) }
    let!(:scan) { create(:security_scan, scan_type: :sast, status: status, pipeline: pipeline, project: project) }
    let(:scan_types) { described_class.scan_types.keys }

    subject(:processing?) { described_class.processing?(pipeline, scan_types) }

    where(:status, :expected) do
      'created'            | true
      'preparing'          | true
      'succeeded'          | false
      'job_failed'         | false
      'report_error'       | false
      'preparation_failed' | false
      'purged'             | false
    end

    with_them do
      it { is_expected.to eq(expected) }

      context 'when scan is in a child pipeline' do
        let_it_be(:parent) { create(:ci_pipeline, project: project) }
        let_it_be(:pipeline) { create(:ci_pipeline, child_of: parent, project: project) }

        it { is_expected.to eq(expected) }
      end

      context 'when checking an in-scope scan type' do
        let(:scan_types) { [:sast] }

        it { is_expected.to eq(expected) }
      end

      context 'when checking a scan type for which there is no scan' do
        let(:scan_types) { [:dast] }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '.without_errors' do
    let_it_be(:scan_1) { create(:security_scan, :with_error) }
    let_it_be(:scan_2) { create(:security_scan) }

    subject { described_class.without_errors }

    it { is_expected.to contain_exactly(scan_2) }
  end

  describe '.latest' do
    let_it_be(:latest_scan) { create(:security_scan, latest: true) }
    let_it_be(:retried_scan) { create(:security_scan, latest: false) }

    subject { described_class.latest }

    it { is_expected.to match_array([latest_scan]) }
  end

  describe '.stale' do
    let(:gitlab_dot_com) { false }
    let(:over_retention_period) { 91.days.ago }

    let_it_be(:thirty_days_stale_succeeded_scan) { create(:security_scan, status: :succeeded, created_at: 31.days.ago) }
    let_it_be(:sixty_days_stale_succeeded_scan) { create(:security_scan, status: :succeeded, created_at: 61.days.ago) }
    let_it_be(:ninety_days_stale_succeeded_scan) { create(:security_scan, status: :succeeded, created_at: 91.days.ago) }
    let_it_be(:stale_failed_scan) { create(:security_scan, status: :preparation_failed, created_at: 91.days.ago) }
    let_it_be(:stale_created_scan) { create(:security_scan, status: :created, created_at: 91.days.ago) }
    let_it_be(:stale_job_failed_scan) { create(:security_scan, status: :job_failed, created_at: 91.days.ago) }
    let_it_be(:stale_report_errored_scan) { create(:security_scan, status: :report_error, created_at: 91.days.ago) }
    let_it_be(:stale_preparing_scan) { create(:security_scan, status: :preparing, created_at: 91.days.ago) }

    let(:expected_scans) do
      [ninety_days_stale_succeeded_scan, stale_failed_scan, stale_created_scan,
        stale_job_failed_scan, stale_report_errored_scan, stale_preparing_scan]
    end

    subject { described_class.stale }

    before do
      allow(Gitlab).to receive(:com?).and_return(gitlab_dot_com)
      create(:security_scan, status: :succeeded)
      create(:security_scan, status: :preparation_failed)
      create(:security_scan, status: :purged, created_at: over_retention_period)
    end

    it { is_expected.to match_array(expected_scans) }

    context 'for Gitlab.com' do
      let(:gitlab_dot_com) { true }
      let(:over_retention_period) { 31.days.ago }

      let(:expected_scans) do
        [ninety_days_stale_succeeded_scan, stale_failed_scan, stale_created_scan,
          stale_job_failed_scan, stale_report_errored_scan, stale_preparing_scan,
          sixty_days_stale_succeeded_scan, thirty_days_stale_succeeded_scan]
      end

      it { is_expected.to match_array(expected_scans) }
    end
  end

  describe '.ordered_by_created_at_and_id' do
    let_it_be(:created_at) { Time.zone.now }
    let_it_be(:scan_1) { create(:security_scan, created_at: created_at) }
    let_it_be(:scan_2) { create(:security_scan, created_at: created_at) }
    let_it_be(:scan_3) { create(:security_scan, created_at: created_at - 1.minute) }

    subject { described_class.ordered_by_created_at_and_id }

    it { is_expected.to eq([scan_3, scan_1, scan_2]) }
  end

  describe '.with_warnings' do
    let_it_be(:scan_1) { create(:security_scan) }
    let_it_be(:scan_2) { create(:security_scan, :with_warning) }

    subject { described_class.with_warnings }

    it { is_expected.to contain_exactly(scan_2) }
  end

  describe '.with_errors' do
    let_it_be(:scan_1) { create(:security_scan, :with_error) }
    let_it_be(:scan_2) { create(:security_scan) }

    subject { described_class.with_errors }

    it { is_expected.to contain_exactly(scan_1) }
  end

  describe '.processing' do
    let_it_be(:created_scan) { create(:security_scan, status: :created) }
    let_it_be(:preparing_scan) { create(:security_scan, status: :preparing) }

    before_all do
      ::Security::Scan.statuses.except('created', 'preparing').each_key do |status|
        create(:security_scan, status: status)
      end
    end

    subject { described_class.processing }

    it { is_expected.to match_array([created_scan, preparing_scan]) }
  end

  describe '#security_report (private)' do
    let(:artifact) { create(:ee_ci_job_artifact, :dast) }

    context 'when scanner_external_id is nil (single-scanner artifact)' do
      let(:scan) { create(:security_scan, build: artifact.job) }

      it 'returns a report for the artifact' do
        expect(scan.send(:security_report)).to be_a(::Gitlab::Ci::Reports::Security::Report)
      end
    end

    context 'when scanner_external_id is set (multi-run artifact)' do
      let(:scanner_external_id) { artifact.security_report.scanner.external_id }
      let(:scan) { create(:security_scan, build: artifact.job, scanner_external_id: scanner_external_id) }

      it 'returns the report whose scanner matches scanner_external_id' do
        expect(scan.send(:security_report).scanner.external_id).to eq(scanner_external_id)
      end

      context 'when no report matches the scanner_external_id' do
        let(:scan) { create(:security_scan, build: artifact.job, scanner_external_id: 'unknown-tool') }

        it 'returns nil' do
          expect(scan.send(:security_report)).to be_nil
        end
      end
    end

    context 'when sub-reports share scanner_external_id but differ by scan_type (inferred-type fan-out)' do
      let(:scanner) { instance_double(::Gitlab::Ci::Reports::Security::Scanner, external_id: 'semgrep') }
      let(:sast_finding) { instance_double(::Gitlab::Ci::Reports::Security::Finding) }
      let(:secret_finding) { instance_double(::Gitlab::Ci::Reports::Security::Finding) }

      let(:sast_report) do
        instance_double(::Gitlab::Ci::Reports::Security::Report,
          type: 'sast', scanner: scanner, findings: [sast_finding])
      end

      let(:secret_report) do
        instance_double(::Gitlab::Ci::Reports::Security::Report,
          type: 'secret_detection', scanner: scanner, findings: [secret_finding])
      end

      let(:sast_scan) do
        create(:security_scan, build: artifact.job, scan_type: 'sast', scanner_external_id: 'semgrep')
      end

      let(:secret_scan) do
        create(:security_scan, build: artifact.job, scan_type: 'secret_detection', scanner_external_id: 'semgrep')
      end

      let(:artifact_double) { instance_double(Ci::JobArtifact, security_reports: [sast_report, secret_report]) }

      before do
        allow(sast_scan).to receive(:job_artifact).and_return(artifact_double)
        allow(secret_scan).to receive(:job_artifact).and_return(artifact_double)
      end

      it 'returns the sast sub-report findings for the sast scan' do
        expect(sast_scan.report_findings).to eq([sast_finding])
      end

      it 'returns the secret_detection sub-report findings for the secret_detection scan' do
        expect(secret_scan.report_findings).to eq([secret_finding])
      end
    end
  end

  describe '#job_artifact (private)' do
    let_it_be(:build) { create(:ee_ci_build) }

    let(:scan) { create(:security_scan, build: build, scan_type: 'sast') }

    context 'when a direct file_type artifact exists' do
      let_it_be(:sast_artifact) { create(:ee_ci_job_artifact, :sast, job: build) }

      it 'returns the direct file_type artifact' do
        expect(scan.send(:job_artifact)).to eq(sast_artifact)
      end
    end

    context 'when no direct file_type artifact exists but a SARIF artifact does' do
      let_it_be(:sarif_artifact) { create(:ee_ci_job_artifact, :sarif, job: build) }

      it 'falls back to the SARIF artifact' do
        expect(scan.send(:job_artifact)).to eq(sarif_artifact)
      end
    end

    context 'when neither a direct nor a SARIF artifact exists' do
      it 'returns nil' do
        expect(scan.send(:job_artifact)).to be_nil
      end
    end
  end

  describe '#report_findings' do
    let_it_be(:artifact) { create(:ee_ci_job_artifact, :dast) }
    let_it_be(:scan) { create(:security_scan, build: artifact.job) }
    let(:artifact_finding_uuids) { artifact.security_report.findings.map(&:uuid) }

    subject { scan.report_findings.map(&:uuid) }

    it { is_expected.to match_array(artifact_finding_uuids) }
  end

  describe '#report_primary_identifiers' do
    it 'returns the matching primary_identifiers' do
      artifact = create(:ee_ci_job_artifact, :sast_semgrep_for_gosec)
      scan = create(:security_scan, scan_type: 'sast', build: artifact.job)

      expect(scan.report_primary_identifiers).to match_array(
        artifact.security_report.primary_identifiers
      )
    end
  end

  describe '#processing_errors' do
    let(:scan) { build(:security_scan, :with_error) }

    subject { scan.processing_errors }

    it { is_expected.to eq([{ 'type' => 'ParsingError', 'message' => 'Unknown error happened' }]) }
  end

  describe '#processing_errors=' do
    let(:scan) { create(:security_scan) }

    subject(:set_processing_errors) { scan.processing_errors = [:foo] }

    it 'sets the processing errors' do
      expect { set_processing_errors }.to change { scan.info['errors'] }.from(nil).to([:foo])
    end
  end

  describe '#add_processing_error!' do
    let(:error) { { type: 'foo', message: 'bar' } }

    subject(:add_processing_error) { scan.add_processing_error!(error) }

    context 'when the scan does not have any errors' do
      let(:scan) { create(:security_scan) }

      it 'persists the error' do
        expect { add_processing_error }.to change { scan.reload.info['errors'] }.from(nil).to([{ 'type' => 'foo', 'message' => 'bar' }])
      end
    end

    context 'when the scan already has some errors' do
      let(:scan) { create(:security_scan, :with_error) }

      it 'persists the new error with the existing ones' do
        expect { add_processing_error }.to change { scan.reload.info['errors'] }.from([{ 'type' => 'ParsingError', 'message' => 'Unknown error happened' }])
                                                                                .to([{ 'type' => 'ParsingError', 'message' => 'Unknown error happened' }, { 'type' => 'foo', 'message' => 'bar' }])
      end
    end
  end

  describe '#remediations_proxy' do
    let(:mock_file) { instance_double(JobArtifactUploader) }
    let(:scan) { create(:security_scan, :with_findings) }

    subject { scan.remediations_proxy }

    context 'when the artifact exists' do
      before do
        allow_next_found_instance_of(Ci::JobArtifact) do |artifact|
          allow(artifact).to receive(:file).and_return(mock_file)
        end
      end

      it { is_expected.to be_an_instance_of(Security::RemediationsProxy).and have_attributes(file: mock_file) }
    end

    context 'when the artifact is removed' do
      before do
        scan.build.job_artifacts.delete_all
      end

      it { is_expected.to be_an_instance_of(Security::RemediationsProxy).and have_attributes(file: nil) }
    end
  end

  it_behaves_like 'having unique enum values'

  describe "#scanner" do
    let_it_be(:scan) { create(:security_scan, scan_type: :dependency_scanning) }
    let_it_be(:artifact) { create(:ee_ci_job_artifact, :dependency_scanning, job: scan.build, project: scan.project) }
    let_it_be(:gemnasium_maven_scanner) { create(:vulnerabilities_scanner, project: scan.project, external_id: 'gemnasium-maven') }

    it 'returns the matching vulnerability scanner' do
      expect(scan.scanner).to eq(gemnasium_maven_scanner)
    end
  end

  context 'with loose foreign key on security_scans.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:security_scan, project: parent) }
    end
  end

  describe '.partial' do
    let_it_be(:sast_partial_scan) { create(:security_scan, scan_type: :sast) }

    before do
      create(:security_scan, scan_type: :sast)
      create(:vulnerabilities_partial_scan, scan: sast_partial_scan)
    end

    it 'returns only scans that have associated partial scan records' do
      expect(described_class.partial).to match_array([sast_partial_scan])
    end
  end

  describe '.stale_after' do
    it 'returns the configured duration from application settings' do
      allow(::Gitlab::CurrentSettings).to receive(:security_scan_stale_after_days).and_return(45)

      expect(described_class.stale_after).to eq(45.days)
    end

    it 'converts the configured days to a duration' do
      allow(::Gitlab::CurrentSettings).to receive(:security_scan_stale_after_days).and_return(30)

      expect(described_class.stale_after).to eq(30.days)
    end
  end

  describe '#pipeline' do
    it_behaves_like 'a partition-pruned pipeline association' do
      # .reload resets the :pipeline association preloaded by the factory's default block
      let(:related_resource) { create(:security_scan, pipeline: pipeline).reload }
    end
  end
end
