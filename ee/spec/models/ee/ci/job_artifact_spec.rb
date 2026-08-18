# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobArtifact, feature_category: :job_artifacts do
  using RSpec::Parameterized::TableSyntax

  describe 'Geo replication', feature_category: :geo_replication do
    include EE::GeoHelpers

    before do
      stub_artifacts_object_storage
    end

    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:job_artifact_state)
          .class_name('Geo::JobArtifactState')
          .inverse_of(:job_artifact)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let_it_be(:job) { create(:ci_build) }

      let(:verifiable_model_record) do
        build(:ci_job_artifact, job: job, partition_id: job.partition_id)
      end

      let(:unverifiable_model_record) do
        build(:ci_job_artifact, :remote_store, job: job, partition_id: job.partition_id)
      end
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, group: group_2) }
      let_it_be(:job_1) { create(:ci_build, project: project_1) }
      let_it_be(:job_2) { create(:ci_build, project: project_2) }
      let_it_be(:job_3) { create(:ci_build, project: project_3) }
      let_it_be(:job_4) { create(:ci_build, project: project_1) }

      # Job artifact for the root group
      let_it_be(:first_replicable_and_in_selective_sync) do
        create(:ci_job_artifact, job: job_1)
      end

      # Job artifact for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) do
        create(:ci_job_artifact, job: job_2)
      end

      # Job artifact for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        create(:ci_job_artifact, :remote_store, job: job_4)
      end

      # Job artifact for a group not in selective sync
      let_it_be(:last_replicable_and_not_in_selective_sync) do
        create(:ci_job_artifact, job: job_3)
      end

      include_examples 'Geo Framework selective sync behavior'

      describe '#destroy' do
        let_it_be_with_refind(:primary) { create(:geo_node, :primary) }

        before do
          stub_current_geo_node(primary)
        end

        context 'when pipeline is destroyed' do
          it 'creates a Geo delete event async' do
            job_artifact = create(:ee_ci_job_artifact, :archive)

            payload = {
              model_record_id: job_artifact.id,
              blob_path: job_artifact.file.relative_path,
              uploader_class: 'JobArtifactUploader'
            }

            expect(::Geo::JobArtifactReplicator)
              .to receive(:bulk_create_delete_events_async)
              .with([payload])
              .once

            job_artifact.job.pipeline.destroy!
          end
        end

        context 'when job artifact destroy fails' do
          it 'does not create a JobArtifactDeletedEvent' do
            job_artifact = create(:ee_ci_job_artifact, :archive)

            allow(job_artifact).to receive(:destroy!)
                               .and_raise(ActiveRecord::RecordNotDestroyed)

            expect { job_artifact.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
                                            .and not_change { Ci::JobArtifact.count }
          end
        end
      end
    end
  end

  describe '.file_types_for_report' do
    it 'returns the report file types for the report type' do
      expect(described_class.file_types_for_report(:sbom)).to match_array(%w[cyclonedx])
    end

    context 'when given an unrecognized report type' do
      it 'raises error' do
        expect do
          described_class.file_types_for_report(:blah)
        end.to raise_error(ArgumentError, "Unrecognized report type: blah")
      end
    end
  end

  describe '.of_report_type' do
    subject { described_class.of_report_type(report_type) }

    describe 'license_scanning_reports' do
      let(:report_type) { :license_scanning }

      let_it_be(:artifact) { create(:ee_ci_job_artifact, :license_scanning) }

      it { is_expected.to eq([artifact]) }
    end

    describe 'cluster_image_scanning_reports' do
      let(:report_type) { :cluster_image_scanning }

      let_it_be(:artifact) { create(:ee_ci_job_artifact, :cluster_image_scanning) }

      it { is_expected.to eq([artifact]) }
    end

    describe 'metrics_reports' do
      let(:report_type) { :metrics }

      context 'when there is a metrics report' do
        let!(:artifact) { create(:ee_ci_job_artifact, :metrics) }

        it { is_expected.to eq([artifact]) }
      end

      context 'when there is no metrics reports' do
        let!(:artifact) { create(:ee_ci_job_artifact, :trace) }

        it { is_expected.to be_empty }
      end
    end

    describe 'coverage_fuzzing_reports' do
      let(:report_type) { :coverage_fuzzing }

      context 'when there is a metrics report' do
        let!(:artifact) { create(:ee_ci_job_artifact, :coverage_fuzzing) }

        it { is_expected.to eq([artifact]) }
      end

      context 'when there is no coverage fuzzing reports' do
        let!(:artifact) { create(:ee_ci_job_artifact, :trace) }

        it { is_expected.to be_empty }
      end
    end

    describe 'api_fuzzing_reports' do
      let(:report_type) { :api_fuzzing }

      context 'when there is a metrics report' do
        let!(:artifact) { create(:ee_ci_job_artifact, :api_fuzzing) }

        it { is_expected.to eq([artifact]) }
      end

      context 'when there is no coverage fuzzing reports' do
        let!(:artifact) { create(:ee_ci_job_artifact, :trace) }

        it { is_expected.to be_empty }
      end
    end

    describe 'sbom_reports' do
      let(:report_type) { :sbom }

      context 'when there is an sbom report' do
        let!(:artifact) { create(:ee_ci_job_artifact, :cyclonedx) }

        it { is_expected.to match_array([artifact]) }
      end

      context 'when there is no sbom report' do
        let!(:artifact) { create(:ee_ci_job_artifact, :trace) }

        it { is_expected.to be_empty }
      end
    end
  end

  describe '.security_reports' do
    context 'when the `file_types` parameter is provided' do
      let_it_be(:sast_artifact) { create(:ee_ci_job_artifact, :sast) }

      subject { described_class.security_reports(file_types: file_types) }

      context 'when the provided file_types is array' do
        let(:file_types) { %w[secret_detection] }

        context 'when there is a security report with the given value' do
          let!(:secret_detection_artifact) { create(:ee_ci_job_artifact, :secret_detection) }

          it { is_expected.to eq([secret_detection_artifact]) }
        end

        context 'when there are no security reports with the given value' do
          it { is_expected.to be_empty }
        end
      end

      context 'when the provided file_types is string' do
        let(:file_types) { 'secret_detection' }
        let!(:secret_detection_artifact) { create(:ee_ci_job_artifact, :secret_detection) }

        it { is_expected.to eq([secret_detection_artifact]) }
      end

      context 'when the provided file_types is cyclonedx' do
        let(:file_types) { 'cyclonedx' }
        let(:cyclonedx_artifact) { create(:ee_ci_job_artifact, :cyclonedx) }

        it { is_expected.to eq([cyclonedx_artifact]) }
      end
    end

    context 'when the file_types parameter is not provided' do
      subject { described_class.security_reports }

      context 'when there is a security report' do
        let!(:sast_artifact) { create(:ee_ci_job_artifact, :sast) }
        let!(:secret_detection_artifact) { create(:ee_ci_job_artifact, :secret_detection) }

        it { is_expected.to match_array([sast_artifact, secret_detection_artifact]) }
      end

      context 'when there are no security reports' do
        let!(:artifact) { create(:ci_job_artifact, :archive) }

        it { is_expected.to be_empty }
      end
    end
  end

  describe '.associated_file_types_for' do
    subject { described_class.associated_file_types_for(file_type) }

    where(:file_type, :result) do
      'license_scanning'    | %w[license_scanning]
      'codequality'         | %w[codequality]
      'browser_performance' | %w[browser_performance performance]
      'load_performance'    | %w[load_performance]
      'quality'             | nil
    end

    with_them do
      it { is_expected.to eq result }
    end
  end

  describe '.search' do
    let_it_be(:project1) do
      create(:project, name: 'project_1_name', path: 'project_1_path', description: 'project_desc_1')
    end

    let_it_be(:project2) do
      create(:project, name: 'project_2_name', path: 'project_2_path', description: 'project_desc_2')
    end

    let_it_be(:project3) do
      create(:project, name: 'another_name', path: 'another_path', description: 'another_description')
    end

    let_it_be(:ci_build1) { create(:ci_build, project: project1) }
    let_it_be(:ci_build2) { create(:ci_build, project: project2) }
    let_it_be(:ci_build3) { create(:ci_build, project: project3) }

    let_it_be(:job_artifact1) { create(:ci_job_artifact, job: ci_build1) }
    let_it_be(:job_artifact2) { create(:ci_job_artifact, job: ci_build2) }
    let_it_be(:job_artifact3) { create(:ci_job_artifact, job: ci_build3) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(job_artifact1, job_artifact2, job_artifact3)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all job artifacts' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches' do
        context 'with project association' do
          it 'filters by project path' do
            result = described_class.search('project_1_PATH')

            expect(result).to contain_exactly(job_artifact1)
          end

          it 'filters by project name' do
            result = described_class.search('Project_2_NAME')

            expect(result).to contain_exactly(job_artifact2)
          end

          it 'filters project description' do
            result = described_class.search('Project_desc')

            expect(result).to contain_exactly(job_artifact1, job_artifact2)
          end
        end
      end
    end
  end

  describe '#security_report' do
    let_it_be(:job) { create(:ci_build) }

    let(:job_artifact) { create(:ee_ci_job_artifact, :sast, job: job) }
    let(:validate) { false }
    let(:security_report) { job_artifact.security_report(validate: validate) }

    subject(:findings_count) { security_report.findings.length }

    it { is_expected.to be(5) }

    context 'for different types' do
      where(:file_type, :security_report?) do
        :performance            | false
        :sast                   | true
        :secret_detection       | true
        :dependency_scanning    | true
        :container_scanning     | true
        :cluster_image_scanning | true
        :dast                   | true
        :coverage_fuzzing       | true
        :cyclonedx              | true
      end

      with_them do
        let(:job_artifact) { create(:ee_ci_job_artifact, file_type, job: job) }

        subject { security_report.is_a?(::Gitlab::Ci::Reports::Security::Report) }

        it { is_expected.to be(security_report?) }
      end
    end

    context 'when the artifact is a SARIF report' do
      let(:job_artifact) { create(:ee_ci_job_artifact, :sarif, job: job) }

      it 'returns a parsed report', :aggregate_failures do
        expect(security_report).to be_a(::Gitlab::Ci::Reports::Security::Report)
        expect(security_report.errors).to be_empty
        expect(security_report.findings).not_to be_empty
      end
    end

    context 'when the parsing fails' do
      let(:job_artifact) { create(:ee_ci_job_artifact, :sast, job: job) }
      let(:errors) { security_report.errors }

      before do
        allow(::Gitlab::Ci::Parsers).to receive(:fabricate!).and_raise(:foo)
      end

      it 'returns an errored report instance' do
        expect(errors).to eql([{ type: 'ParsingError', message: 'Failed to parse security report' }])
      end
    end

    describe 'schema validation' do
      before do
        allow(::Gitlab::Ci::Parsers).to receive(:fabricate!).and_return(mock_parser)
      end

      let(:mock_parser) { double(:parser, parse!: true) }
      let(:expected_parser_args) do
        ['sast', instance_of(String), instance_of(::Gitlab::Ci::Reports::Security::Report),
          { signatures_enabled: false, validate: validate }]
      end

      context 'when validate is false' do
        let(:validate) { false }

        it 'calls the parser with the correct arguments' do
          security_report

          expect(::Gitlab::Ci::Parsers).to have_received(:fabricate!).with(*expected_parser_args)
        end
      end

      context 'when validate is true' do
        let(:validate) { true }

        it 'calls the parser with the correct arguments' do
          security_report

          expect(::Gitlab::Ci::Parsers).to have_received(:fabricate!).with(*expected_parser_args)
        end
      end
    end

    context 'when the artifact file is empty' do
      let(:job_artifact) { create(:ee_ci_job_artifact, :empty_sast_report) }

      it 'returns a report with an error' do
        report = job_artifact.security_report

        expect(report).to be_errored
        expect(report.errors).to include(
          hash_including(
            type: 'EmptyFile',
            message: 'Report file is empty'
          )
        )
      end

      it 'does not have a scanner' do
        expect(job_artifact.security_report.scanner).to be_nil
      end
    end

    context 'with cyclonedx' do
      let(:job_artifact) { create(:ee_ci_job_artifact, :cyclonedx, job: job) }

      it 'considers multiple reports via Sbom::Reports' do
        expect(::Gitlab::VulnerabilityScanning::SecurityReportBuilder).to receive(:new)
          .with(sbom_reports: be_a(::Gitlab::Ci::Reports::Sbom::Reports), project: job.project, pipeline: job.pipeline)
          .and_call_original

        security_report
      end
    end
  end

  describe '#clear_security_report' do
    let_it_be(:job) { create(:ci_build) }

    let(:job_artifact) { create(:ee_ci_job_artifact, :sast, job: job) }

    subject(:clear_security_report) { job_artifact.clear_security_report }

    before do
      job_artifact.security_report # Memoize first
      allow(::Gitlab::Ci::Reports::Security::Report).to receive(:new).and_call_original
    end

    it 'clears the security_report' do
      clear_security_report
      job_artifact.security_report

      # This entity class receives the call twice
      # because of the way MergeReportsService is implemented.
      expect(::Gitlab::Ci::Reports::Security::Report).to have_received(:new).twice
    end
  end
end
