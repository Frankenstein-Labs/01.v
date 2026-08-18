# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::FindingsFinder, feature_category: :vulnerability_management do
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:pipeline, freeze: false) { create(:ci_pipeline) }
  let_it_be(:build_1, freeze: false) { create(:ci_build, :success, name: 'dependency_scanning', pipeline: pipeline) }
  let_it_be(:build_2, freeze: false) { create(:ci_build, :success, name: 'sast', pipeline: pipeline) }
  let_it_be(:artifact_ds, freeze: false) { create(:ee_ci_job_artifact, :dependency_scanning, job: build_1) }
  let_it_be(:artifact_sast, freeze: false) { create(:ee_ci_job_artifact, :sast, job: build_2) }
  let_it_be(:report_ds, freeze: false) do
    create(:ci_reports_security_report, pipeline: pipeline, type: :dependency_scanning)
  end

  let_it_be(:report_sast, freeze: false) { create(:ci_reports_security_report, pipeline: pipeline, type: :sast) }

  let(:severity_levels) { nil }
  let(:report_types) { nil }
  let(:scope) { nil }
  let(:scanner) { nil }
  let(:state) { nil }
  let(:service_object) { described_class.new(pipeline, params: params) }
  let(:params) do
    {
      severity: severity_levels,
      report_type: report_types,
      scope: scope,
      scanner: scanner,
      state: state,
      sort: nil,
      first: nil,
      after: nil
    }
  end

  context 'when the pipeline is nil' do
    let(:pipeline) { nil }

    describe '#execute' do
      subject { service_object.execute }

      it { is_expected.to be_empty }
    end
  end

  context 'when the pipeline does not have security findings' do
    describe '#execute' do
      subject { service_object.execute }

      it { is_expected.to be_empty }
    end
  end

  context 'when the pipeline has security findings' do
    let(:findings) { service_object.execute.to_a }
    let(:duplicate_security_finding_uuids) { [Security::Finding.second[:uuid]] }
    let(:expected_uuids) { result_uuids - duplicate_security_finding_uuids }

    before_all do
      ds_content = File.read(artifact_ds.file.path)
      Gitlab::Ci::Parsers::Security::DependencyScanning.parse!(ds_content, report_ds)
      report_ds.merge!(report_ds)
      sast_content = File.read(artifact_sast.file.path)
      Gitlab::Ci::Parsers::Security::Sast.parse!(sast_content, report_sast)
      report_sast.merge!(report_sast)

      findings = { artifact_ds => report_ds, artifact_sast => report_sast }.flat_map do |artifact, report|
        scan = create(:security_scan, :latest_successful, scan_type: artifact.job.name, build: artifact.job)
        scanner_external_id = report.scanner.external_id
        scanner = create(:vulnerabilities_scanner, project: pipeline.project, external_id: scanner_external_id)

        report.findings.flat_map do |finding, _index|
          create(
            :security_finding,
            severity: finding.severity,
            uuid: finding.uuid,
            deduplicated: true,
            scan: scan,
            scanner: scanner
          )
        end
      end

      findings.second.update!(deduplicated: false)

      create(
        :vulnerability_feedback,
        :dismissal,
        project: pipeline.project,
        category: :dependency_scanning,
        finding_uuid: findings.first.uuid
      )

      vulnerability_finding = create(:vulnerabilities_finding, uuid: findings.second.uuid)

      vulnerability = create(:vulnerability, findings: [vulnerability_finding])
      create(:vulnerability_state_transition, vulnerability: vulnerability)
      create(:vulnerabilities_issue_link, vulnerability: vulnerability)
      create(:vulnerabilities_merge_request_link, vulnerability: vulnerability)
    end

    it 'does not parse artifacts' do
      allow(::Gitlab::Ci::Parsers).to receive(:fabricate!)

      service_object.execute

      expect(::Gitlab::Ci::Parsers).not_to have_received(:fabricate!)
    end

    describe '#findings' do
      context 'when the `security_findings` records have `overridden_uuid`s' do
        let(:security_findings) { Security::Finding.by_build_ids(build_1) }
        let(:result_uuids) { Security::Finding.pluck(:uuid) }

        subject { findings.map(&:uuid) }

        before do
          security_findings.each do |security_finding|
            security_finding.update!(overridden_uuid: security_finding.uuid, uuid: SecureRandom.uuid)
          end
        end

        it { is_expected.to match_array(expected_uuids) }
      end
    end

    describe '#execute' do
      before do
        stub_licensed_features(sast: true, dependency_scanning: true)
      end

      describe 'N+1 queries' do
        let(:query_limit) { 11 }

        it 'does not cause N+1 queries' do
          expect { findings }.not_to exceed_query_limit(query_limit)
        end
      end

      describe '#findings' do
        subject { findings.map(&:uuid) }

        context 'with the default parameters' do
          let(:result_uuids) { Security::Finding.pluck(:uuid) }

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when the uuid is provided' do
          let(:uuid) { Security::Finding.first[:uuid] }
          let(:params) do
            {
              uuid: uuid
            }
          end

          it { is_expected.to match_array([uuid]) }
        end

        context 'when the `severity_levels` is provided' do
          context 'when the severity was not overridden' do
            let(:severity_levels) { [:medium] }
            let(:expected_uuids) { Security::Finding.where(severity: 'medium').pluck(:uuid) }

            it { is_expected.to match_array(expected_uuids) }
          end

          context 'when the severity level was overridden' do
            let(:severity_levels) { [:critical] }
            let(:finding_uuid) { Security::Finding.first.uuid }
            let(:vulnerability) { create(:vulnerability, :high_severity, project: pipeline.project) }

            before do
              create(:vulnerabilities_finding,
                vulnerability: vulnerability,
                project: pipeline.project,
                uuid: finding_uuid,
                severity: :high)
              create(:vulnerability_severity_override,
                vulnerability: vulnerability,
                original_severity: :high,
                new_severity: :critical)
              Security::Finding.find_by(uuid: finding_uuid).update!(severity: :critical)
            end

            it 'returns findings filtered by effective severity from security_findings table' do
              expect(findings.map(&:uuid)).to include(finding_uuid)
            end
          end
        end

        context 'when the `report_types` is provided' do
          let(:report_types) { :dependency_scanning }
          let(:result_uuids) do
            Security::Finding.by_scan(Security::Scan.find_by(scan_type: 'dependency_scanning')).pluck(:uuid)
          end

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when the `scope` is provided as `all`' do
          let(:scope) { 'all' }
          let(:result_uuids) { Security::Finding.pluck(:uuid) }

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when the `scanner` is provided' do
          let(:scanner) { report_sast.scanner.external_id }
          let(:expected_uuids) { Security::Finding.by_scan(Security::Scan.find_by(scan_type: 'sast')).pluck(:uuid) }

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when the `state` is provided' do
          let(:dismissed_finding_uuid) { report_ds.findings.first.uuid }
          let(:state) { :dismissed }

          before do
            vulnerability = create(:vulnerability, :dismissed)

            create(:vulnerabilities_finding, vulnerability: vulnerability, uuid: dismissed_finding_uuid)
          end

          it { is_expected.to eq([dismissed_finding_uuid]) }
        end

        context 'when there is a retried build' do
          let(:retried_build) { create(:ci_build, :success, :retried, name: 'dependency_scanning', pipeline: pipeline) }
          let(:artifact) { create(:ee_ci_job_artifact, :dependency_scanning, job: retried_build) }
          let(:report) { create(:ci_reports_security_report, pipeline: pipeline, type: :dependency_scanning) }
          let(:report_types) { :dependency_scanning }
          let(:result_uuids) do
            Security::Finding.by_scan(Security::Scan.find_by(scan_type: 'dependency_scanning')).pluck(:uuid)
          end

          before do
            retried_content = File.read(artifact.file.path)
            Gitlab::Ci::Parsers::Security::DependencyScanning.parse!(retried_content, report)
            report.merge!(report)

            scan = create(:security_scan, scan_type: retried_build.name, build: retried_build, latest: false)

            report.findings.each_with_index do |finding, _index|
              create(
                :security_finding,
                severity: finding.severity,
                uuid: finding.uuid,
                deduplicated: true,
                scan: scan
              )
            end
          end

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when a build has more than one security report artifacts' do
          let(:report_types) { :secret_detection }
          let(:expected_uuids) { secret_detection_report.findings.map(&:uuid) }
          let(:secret_detection_report) do
            create(:ci_reports_security_report, pipeline: pipeline, type: :secret_detection)
          end

          before do
            scan = create(:security_scan, :latest_successful, scan_type: :secret_detection, build: build_2)
            artifact = create(:ee_ci_job_artifact, :secret_detection, job: build_2)
            report_content = File.read(artifact.file.path)

            Gitlab::Ci::Parsers::Security::SecretDetection.parse!(report_content, secret_detection_report)

            secret_detection_report.findings.each_with_index do |finding, _index|
              create(
                :security_finding,
                severity: finding.severity,
                uuid: finding.uuid,
                deduplicated: true,
                scan: scan
              )
            end
          end

          it { is_expected.to match_array(expected_uuids) }
        end

        context 'when a vulnerability already exist for a security finding' do
          let!(:vulnerability_finding) do
            create(
              :vulnerabilities_finding,
              :detected,
              uuid: Security::Finding.first.uuid,
              project: pipeline.project
            )
          end

          subject { findings.map(&:vulnerability).first }

          describe 'the vulnerability is included in results' do
            it { is_expected.to eq(vulnerability_finding.vulnerability) }
          end
        end

        context 'when there is a partial scan' do
          let(:sast_scan) { Security::Scan.find_by(scan_type: 'sast') }
          let(:other_scans) { Security::Scan.id_not_in(sast_scan.id) }

          before do
            create(:vulnerabilities_partial_scan, scan: sast_scan)
          end

          context 'with no params' do
            let(:params) { {} }
            let(:result_uuids) { Security::Finding.pluck(:uuid) }

            it 'returns both full and partial scan results' do
              is_expected.to match_array(expected_uuids)
            end
          end

          context 'when scan_mode is full' do
            let(:params) { { scan_mode: 'full' } }
            let(:result_uuids) { other_scans.flat_map(&:findings).pluck(:uuid) }

            it 'returns only full scan results' do
              is_expected.to match_array(expected_uuids)
            end
          end

          context 'when scan_mode is partial' do
            let(:params) { { scan_mode: 'partial' } }
            let(:result_uuids) { sast_scan.findings.pluck(:uuid) }

            it 'returns only partial scan results' do
              is_expected.to match_array(expected_uuids)
            end
          end
        end
      end
    end

    context 'when there are downstream child pipelines with findings' do
      # `freeze: false` is required in this spec: one or more `let_it_be` subjects
      # cannot be frozen by default (deep_freeze traversal failure, a non-AR
      # subject, or an in-memory mutation that survives reload/refind). Do not
      # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
      # (see gitlab-org/gitlab#602925).
      let_it_be(:child_pipeline, freeze: false) { create(:ci_pipeline, child_of: pipeline) }
      let_it_be(:child_sast_build, freeze: false) do
        create(:ci_build, :success, name: 'sast', pipeline: child_pipeline)
      end

      let_it_be(:child_artifact_sast, freeze: false) do
        create(:ee_ci_job_artifact, :sast_bandit, job: child_sast_build)
      end

      let_it_be(:child_report_sast, freeze: false) do
        create(:ci_reports_security_report, pipeline: child_pipeline, type: :sast)
      end

      before_all do
        sast_content = File.read(child_artifact_sast.file.path)
        Gitlab::Ci::Parsers::Security::Sast.parse!(sast_content, child_report_sast)
        child_report_sast.merge!(child_report_sast)

        { child_artifact_sast => child_report_sast }.flat_map do |artifact, report|
          scan = create(:security_scan, :latest_successful, scan_type: artifact.job.name, build: artifact.job)
          scanner_external_id = report.scanner.external_id
          scanner = create(:vulnerabilities_scanner, project: child_pipeline.project, external_id: scanner_external_id)

          report.findings.flat_map do |finding, _index|
            create(
              :security_finding,
              severity: finding.severity,
              uuid: finding.uuid,
              deduplicated: true,
              scan: scan,
              scanner: scanner
            )
          end
        end
      end

      describe '#execute' do
        subject(:finding_uuids) { findings.map(&:uuid) }

        before do
          stub_licensed_features(sast: true)
        end

        context 'with the default parameters' do
          let(:result_uuids) { Security::Finding.pluck(:uuid) }

          it 'includes child build findings' do
            expect(finding_uuids).to match_array(expected_uuids)
            expect(finding_uuids).to include(*Security::Finding.by_build_ids(child_sast_build).map(&:uuid))
          end
        end

        context 'when the `scanner` is provided' do
          let(:scanner) { child_report_sast.scanner.external_id }

          it 'returns findings belonging to that scanner' do
            expect(finding_uuids).to include(*Security::Finding.by_build_ids(child_sast_build).map(&:uuid))
          end
        end

        context 'when child pipeline findings are in a different partition than active_partition_number' do
          # `freeze: false` is required in this spec: one or more `let_it_be` subjects
          # cannot be frozen by default (deep_freeze traversal failure, a non-AR
          # subject, or an in-memory mutation that survives reload/refind). Do not
          # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
          # (see gitlab-org/gitlab#602925).
          let_it_be(:parent_pipeline, freeze: false) { create(:ci_pipeline) }
          let_it_be(:child_pipeline, freeze: false) { create(:ci_pipeline, child_of: parent_pipeline) }
          let_it_be(:child_build, freeze: false) { create(:ci_build, :success, name: 'sast', pipeline: child_pipeline) }
          let(:bumped_partition_number) { Security::Finding.active_partition_number + 1 }

          let(:service_object) { described_class.new(parent_pipeline, params: {}) }

          before_all do
            scan = create(
              :security_scan,
              :latest_successful,
              scan_type: :sast,
              build: child_build,
              findings_partition_number: Security::Finding.active_partition_number
            )

            scanner = create(:vulnerabilities_scanner, project: child_pipeline.project,
              external_id: 'test_scanner')

            create(
              :security_finding,
              severity: :high,
              uuid: SecureRandom.uuid,
              deduplicated: true,
              scan: scan,
              scanner: scanner,
              partition_number: Security::Finding.active_partition_number
            )
          end

          before do
            allow(Security::Finding).to receive(:active_partition_number)
              .and_return(bumped_partition_number)
          end

          it 'returns child pipeline findings by using partition number from scans' do
            expect(parent_pipeline.security_scans).to be_empty
            expect(child_pipeline.security_scans).not_to be_empty

            expect(service_object.send(:partition_numbers)).to include(1)

            child_finding_uuids = Security::Finding.by_build_ids(child_build).pluck(:uuid)
            expect(finding_uuids).to include(*child_finding_uuids)
          end
        end
      end
    end
  end
end
