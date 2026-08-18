# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Parsers::Security::DependencyScanning, feature_category: :vulnerability_management do
  using RSpec::Parameterized::TableSyntax

  describe '#parse!' do
    let(:project) { artifact.project }
    let(:pipeline) { artifact.job.pipeline }
    let(:artifact) { create(:ee_ci_job_artifact, :dependency_scanning) }
    let(:report) { Gitlab::Ci::Reports::Security::Report.new(artifact.file_type, pipeline, 2.weeks.ago) }

    where(:report_format, :occurrence_count, :identifier_count, :file_path, :package_name, :package_version, :version) do
      :dependency_scanning             | 4 | 7 | 'app/pom.xml' | 'io.netty/netty' | '3.9.1.Final' | '15.0.6'
      :dependency_scanning_remediation | 2 | 3 | 'yarn.lock'   | 'debug'          | '1.0.5'       | '15.0.6'
    end

    with_them do
      let(:artifact) { create(:ee_ci_job_artifact, report_format) }

      before do
        artifact.each_blob { |blob| described_class.parse!(blob, report) }
      end

      it "parses all identifiers and findings" do
        expect(report.findings.length).to eq(occurrence_count)
        expect(report.identifiers.length).to eq(identifier_count)
      end

      it 'generates expected location' do
        location = report.findings.first.location

        expect(location).to be_a(::Gitlab::Ci::Reports::Security::Locations::DependencyScanning)
        expect(location).to have_attributes(
          file_path: file_path,
          package_name: package_name,
          package_version: package_version,
          files: nil
        )
      end

      it "generates expected metadata_version" do
        expect(report.findings.first.metadata_version).to eq(version)
      end
    end

    context "when the report includes files in the location" do
      let(:files_data) do
        [
          { 'path' => 'yarn.lock', 'type' => 'lockfile', 'in_repository' => true },
          { 'path' => 'package.json', 'type' => 'requirements', 'in_repository' => true }
        ]
      end

      let(:report_hash) do
        hash = Gitlab::Json.parse(fixture_file('security_reports/master/gl-dependency-scanning-report.json', dir: 'ee'), symbolize_names: false)
        hash['vulnerabilities'][0]['location']['files'] = files_data
        hash
      end

      before do
        described_class.parse!(report_hash.to_json, report)
      end

      it 'populates files on the location' do
        expect(report.findings.first.location.files).to eq(files_data)
      end
    end

    context "when parsing a vulnerability with a missing location" do
      let(:report_hash) { Gitlab::Json.parse(fixture_file('security_reports/master/gl-sast-report.json'), symbolize_names: true) }

      before do
        report_hash[:vulnerabilities][0][:location] = nil
      end

      it { expect { described_class.parse!(report_hash.to_json, report) }.not_to raise_error }
    end

    context "when parsing a vulnerability with a missing cve" do
      let(:report_hash) { Gitlab::Json.parse(fixture_file('security_reports/master/gl-sast-report.json'), symbolize_names: true) }

      before do
        report_hash[:vulnerabilities][0][:cve] = nil
      end

      it { expect { described_class.parse!(report_hash.to_json, report) }.not_to raise_error }
    end

    context "when vulnerabilities have remediations" do
      let(:artifact) { create(:ee_ci_job_artifact, :dependency_scanning_remediation) }

      before do
        artifact.each_blob { |blob| described_class.parse!(blob, report) }
      end

      it "generates occurrence with expected remediation" do
        occurrence = report.findings.last
        raw_metadata = Gitlab::Json.parse!(occurrence.raw_metadata)

        expect(occurrence.name).to eq("Authentication bypass via incorrect DOM traversal and canonicalization in saml2-js")
        expect(raw_metadata["remediations"].first["summary"]).to eq("Upgrade saml2-js")
        expect(raw_metadata["remediations"].first["diff"]).to start_with("ZGlmZiAtLWdpdCBhL3lhcm4")
      end
    end

    context "when analyzer is gemnasium-python" do
      let(:artifact) { create(:ee_ci_job_artifact, :dependency_scanning_python) }

      before do
        artifact.each_blob { |blob| described_class.parse!(blob, report) }
      end

      it "normalizes package name" do
        occurrence = report.findings.last

        expect(occurrence.location.package_name).to eq('flask')
      end

      context 'when analyzer is not gemnasium-python' do
        let(:report_hash) { Gitlab::Json.parse(fixture_file('security_reports/master/gl-dependency-scanning-report-python.json', dir: 'ee'), symbolize_names: true) }

        before do
          report_hash[:scan][:analyzer][:id] = 'gemnasium'
          described_class.parse!(report_hash.to_json, report)
        end

        it "does not normalize package name" do
          occurrence = report.findings.last

          expect(occurrence.location.package_name).to eq('Flask')
        end
      end

      context 'when analyzer is nil' do
        let(:report_hash) { Gitlab::Json.parse(fixture_file('security_reports/master/gl-dependency-scanning-report-python.json', dir: 'ee'), symbolize_names: true) }

        before do
          report_hash[:scan][:analyzer] = nil
          described_class.parse!(report_hash.to_json, report)
        end

        it "does not normalize package name" do
          occurrence = report.findings.last

          expect(occurrence.location.package_name).to eq('Flask')
        end
      end
    end
  end
end
