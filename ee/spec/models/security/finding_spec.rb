# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Finding, feature_category: :vulnerability_management do
  let_it_be(:scan_1) { create(:security_scan, :latest_successful, scan_type: :sast) }
  let_it_be(:scan_2) { create(:security_scan, :latest_successful, scan_type: :dast) }
  let_it_be_with_refind(:finding_1) { create(:security_finding, :with_finding_data, scan: scan_1) }
  let_it_be_with_refind(:finding_2) { create(:security_finding, :with_finding_data, scan: scan_2) }

  describe 'associations' do
    it { is_expected.to belong_to(:scan).required }
    it { is_expected.to belong_to(:scanner).required }
    it { is_expected.to belong_to(:vulnerability_finding).class_name('Vulnerabilities::Finding') }
    it { is_expected.to have_one(:build).through(:scan) }
    it { is_expected.to have_one(:vulnerability).through(:vulnerability_finding) }

    it do
      is_expected.to have_one(:token_status)
                                .class_name('Security::FindingTokenStatus')
                                .with_foreign_key('security_finding_id')
                                .inverse_of(:security_finding)
    end

    it { is_expected.to have_many(:state_transitions).through(:vulnerability) }
    it { is_expected.to have_many(:issue_links).through(:vulnerability) }
    it { is_expected.to have_many(:external_issue_links).through(:vulnerability) }
    it { is_expected.to have_many(:merge_request_links).through(:vulnerability) }
    it { is_expected.to have_many(:severity_overrides).through(:vulnerability) }

    it do
      is_expected.to have_many(:feedbacks)
                  .with_primary_key('uuid')
                  .class_name('Vulnerabilities::Feedback')
                  .with_foreign_key('finding_uuid')
    end

    it do
      is_expected.to have_many(:finding_enrichments)
                  .with_primary_key('uuid')
                  .with_foreign_key('finding_uuid')
                  .class_name('Security::FindingEnrichment')
                  .inverse_of(:security_finding)
    end

    it do
      is_expected.to have_many(:cve_enrichments)
                  .through(:finding_enrichments)
                  .source(:cve_enrichment)
                  .class_name('PackageMetadata::CveEnrichment')
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:uuid) }

    describe 'finding_data attribute' do
      let(:finding) { build(:security_finding, :with_finding_data, finding_data: finding_data) }

      before do
        finding.validate
      end

      context 'when the finding_data has invalid fields' do
        let(:finding_data) { { remediation_byte_offsets: [{ start_byte: :foo, end_byte: 20 }] } }

        it 'adds errors' do
          expect(finding.errors.details.keys).to include(:finding_data)
        end
      end

      context 'when the finding_data has valid fields' do
        let(:finding_data) { { remediation_byte_offsets: [{ start_byte: 0, end_byte: 20 }] } }

        it 'does not add errors' do
          expect(finding.errors.details.keys).not_to include(:finding_data)
        end
      end
    end
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:scan_type).to(:scan).allow_nil }
  end

  describe '#unverified?' do
    subject(:unverified?) { finding.unverified? }

    context 'when the finding name has the unverified prefix' do
      let(:finding) do
        build(:security_finding, :with_finding_data, finding_data: { name: '(Unverified) Example finding' })
      end

      it { is_expected.to be(true) }
    end

    context 'when the finding name does not have the unverified prefix' do
      let(:finding) do
        build(:security_finding, :with_finding_data, finding_data: { name: 'Example finding' })
      end

      it { is_expected.to be(false) }
    end
  end

  describe '.by_uuid' do
    subject { described_class.by_uuid(finding_1.uuid) }

    it { is_expected.to match_array([finding_1]) }
  end

  describe '.by_build_ids' do
    subject { described_class.by_build_ids(finding_1.scan.build_id) }

    it { with_cross_joins_prevented { is_expected.to match_array([finding_1]) } }
  end

  describe '.by_severity_levels' do
    let(:expected_findings) { [finding_2] }

    subject { described_class.by_severity_levels(:critical) }

    before do
      finding_1.update! severity: :high
      finding_2.update! severity: :critical
    end

    it { is_expected.to match_array(expected_findings) }
  end

  describe '.by_report_types' do
    let(:expected_findings) { [finding_1] }

    subject { described_class.by_report_types(:sast) }

    it { is_expected.to match_array(expected_findings) }
  end

  describe '.malicious' do
    let_it_be(:glam_finding) do
      create(:security_finding, :with_finding_data, scan: scan_1,
        identifiers: [create(:ci_reports_security_identifier, external_id: 'GLAM-2024-1234').to_hash])
    end

    let_it_be(:mal_finding) do
      create(:security_finding, :with_finding_data, scan: scan_1,
        identifiers: [create(:ci_reports_security_identifier, external_id: 'MAL-2024-5678').to_hash])
    end

    subject { described_class.malicious }

    it 'returns only findings carrying a GLAM-/MAL- identifier' do
      is_expected.to match_array([glam_finding, mal_finding])
    end

    it 'excludes findings without a malware identifier' do
      is_expected.not_to include(finding_1, finding_2)
    end

    context 'when the malware prefix is a secondary identifier' do
      let_it_be(:secondary_finding) do
        create(:security_finding, :with_finding_data, scan: scan_1,
          identifiers: [
            create(:ci_reports_security_identifier, external_id: 'CVE-2024-0001').to_hash,
            create(:ci_reports_security_identifier, external_id: 'MAL-2024-9999').to_hash
          ])
      end

      it { is_expected.to include(secondary_finding) }
    end

    context 'when a finding has no identifiers' do
      let_it_be(:no_identifiers_finding) do
        create(:security_finding, :with_finding_data, scan: scan_1, identifiers: [])
      end

      it { is_expected.not_to include(no_identifiers_finding) }
    end

    context 'when finding_data has no identifiers key' do
      # `finding_data` is NOT NULL DEFAULT '{}', so it can never be SQL NULL.
      # Built without `:with_finding_data`, it defaults to `{}` (no identifiers
      # key), exercising the COALESCE branch of the scope.
      let_it_be(:empty_finding_data_finding) { create(:security_finding, scan: scan_1) }

      it { is_expected.not_to include(empty_finding_data_finding) }
    end
  end

  describe '.by_scanners' do
    subject { described_class.by_scanners(finding_1.scanner) }

    it { is_expected.to match_array([finding_1]) }
  end

  describe '.by_state' do
    context 'when the state is `detected`' do
      subject(:findings) { described_class.by_state(:detected) }

      before do
        create(:vulnerabilities_finding, :detected, uuid: finding_2.uuid)
      end

      it 'returns findings that are associated with "detected vulnerabilities" along with the recently detected ones' do
        expect(findings).to match_array([finding_1, finding_2])
      end
    end

    context 'when the state is `dismissed`' do
      subject { described_class.by_state(:dismissed) }

      before do
        create(:vulnerabilities_finding, :dismissed, uuid: finding_1.uuid)
      end

      it { is_expected.to match_array([finding_1]) }
    end

    context 'when the state is `confirmed`' do
      subject { described_class.by_state(:confirmed) }

      before do
        create(:vulnerabilities_finding, :confirmed, uuid: finding_1.uuid)
      end

      it { is_expected.to match_array([finding_1]) }
    end

    context 'when the state is `resolved`' do
      subject { described_class.by_state(:resolved) }

      before do
        create(:vulnerabilities_finding, :resolved, uuid: finding_1.uuid)
      end

      it { is_expected.to match_array([finding_1]) }
    end
  end

  describe '.by_project_id_and_pipeline_ids' do
    let_it_be(:project) { create(:project) }
    let_it_be(:pipeline_1) { create(:ee_ci_pipeline, :success, project: project) }
    let_it_be(:pipeline_2) { create(:ee_ci_pipeline, :success, project: project) }
    let_it_be(:pipeline_3) { create(:ee_ci_pipeline, :success, project: project) }

    let_it_be(:finding_1) do
      create(:security_finding,
        :with_finding_data,
        scan: create(:security_scan, project: project, pipeline: pipeline_1, status: :succeeded)
      )
    end

    let_it_be(:finding_2) do
      create(:security_finding,
        :with_finding_data,
        scan: create(:security_scan, project: project, pipeline: pipeline_2, status: :succeeded)
      )
    end

    let_it_be(:finding_3) do
      create(:security_finding,
        :with_finding_data,
        scan: create(:security_scan, project: project, pipeline: pipeline_3, status: :succeeded)
      )
    end

    subject(:findings) { described_class.by_project_id_and_pipeline_ids(project.id, [pipeline_1.id, pipeline_2.id]) }

    it { is_expected.to contain_exactly(finding_1, finding_2) }

    context 'when the pipelines belongs to different project' do
      let_it_be(:project) { create(:project) }

      it { is_expected.to be_empty }
    end
  end

  describe '.by_project_id_and_uuid' do
    let_it_be(:project_a) { create(:project) }
    let_it_be(:project_b) { create(:project) }

    let_it_be(:pipeline_a1) { create(:ee_ci_pipeline, :success, project: project_a) }
    let_it_be(:pipeline_a2) { create(:ee_ci_pipeline, :success, project: project_a) }
    let_it_be(:pipeline_b1) { create(:ee_ci_pipeline, :success, project: project_b) }

    let_it_be(:scan_a1) do
      create(:security_scan, project: project_a, pipeline: pipeline_a1, scan_type: :secret_detection,
        status: :succeeded)
    end

    let_it_be(:scan_a2) do
      create(:security_scan, project: project_a, pipeline: pipeline_a2, scan_type: :secret_detection,
        status: :succeeded)
    end

    let_it_be(:scan_b1) do
      create(:security_scan, project: project_b, pipeline: pipeline_b1, scan_type: :secret_detection,
        status: :succeeded)
    end

    let_it_be(:uuid) { SecureRandom.uuid }

    let_it_be(:sf_a1) { create(:security_finding, :with_finding_data, uuid: uuid, scan: scan_a1) }
    let_it_be(:sf_a2) { create(:security_finding, :with_finding_data, uuid: uuid, scan: scan_a2) }
    let_it_be(:sf_b1) { create(:security_finding, :with_finding_data, uuid: uuid, scan: scan_b1) }
    let_it_be(:irrelevant) { create(:security_finding, :with_finding_data, scan: scan_a1) }

    it 'returns findings for the given project and uuid only' do
      expect(described_class.by_project_id_and_uuid(project_a.id, 1, uuid))
        .to contain_exactly(sf_a1, sf_a2)
    end

    it 'excludes findings from other projects even with the same uuid' do
      expect(described_class.by_project_id_and_uuid(project_b.id, 1, uuid))
        .to contain_exactly(sf_b1)
    end

    it 'returns empty when uuid does not match' do
      expect(described_class.by_project_id_and_uuid(project_a.id, 1, SecureRandom.uuid))
        .to be_empty
    end

    it 'skips partition filter when partitions is nil' do
      expect(described_class.by_project_id_and_uuid(project_a.id, nil, uuid))
        .to contain_exactly(sf_a1, sf_a2)
    end

    it 'skips partition filter when partitions is []' do
      expect(described_class.by_project_id_and_uuid(project_a.id, [], uuid))
        .to contain_exactly(sf_a1, sf_a2)
    end
  end

  describe '.undismissed_by_vulnerability' do
    let(:expected_findings) { [finding_2] }

    subject { described_class.undismissed_by_vulnerability }

    before do
      create(:vulnerabilities_finding, :dismissed, uuid: finding_1.uuid)
    end

    it { is_expected.to match_array(expected_findings) }
  end

  describe '.ordered' do
    let_it_be(:finding_3) { create(:security_finding, :with_finding_data, severity: :critical) }
    let_it_be(:finding_4) { create(:security_finding, :with_finding_data, severity: :critical) }

    let(:expected_findings) { [finding_3, finding_4, finding_1, finding_2] }

    before do
      finding_1.update!(severity: :high)
      finding_2.update!(severity: :low)
    end

    context "when order is not given" do
      subject { described_class.ordered }

      it "ordered with descending severity" do
        is_expected.to eq(expected_findings)
      end
    end

    context "when order is given" do
      let(:expected_findings) { [finding_2, finding_1, finding_3, finding_4] }

      subject { described_class.ordered('severity_asc') }

      it "ordered with descending severity" do
        is_expected.to eq(expected_findings)
      end
    end
  end

  describe '.deduplicated' do
    let(:expected_findings) { [finding_1] }

    subject { described_class.deduplicated }

    before do
      finding_1.update! deduplicated: true
      finding_2.update! deduplicated: false
    end

    it { is_expected.to eq(expected_findings) }
  end

  describe '.latest_scan' do
    let(:scan_old) { create(:security_scan, :latest_successful, scan_type: :dast, latest: false) }
    let(:finding_old) { create(:security_finding, :with_finding_data, scan: scan_old) }
    let(:expected_findings) { [finding_1, finding_2] }

    subject { described_class.latest_scan }

    it do
      expect(described_class.by_report_types(:dast)).to contain_exactly(finding_old, finding_2)
      is_expected.to match_array(expected_findings)
    end
  end

  describe '.false_positives' do
    let_it_be(:finding_without_data) { create(:security_finding) }
    let_it_be(:finding_1) { create(:security_finding, :with_finding_data, false_positive: true) }
    let_it_be(:finding_2) { create(:security_finding, :with_finding_data, false_positive: false) }

    subject { described_class.false_positives }

    it { is_expected.to contain_exactly(finding_1) }
  end

  describe '.non_false_positives' do
    let_it_be(:finding_1) { create(:security_finding, :with_finding_data, false_positive: true) }
    let_it_be(:finding_2) { create(:security_finding, :with_finding_data, false_positive: false) }

    subject { described_class.non_false_positives }

    it { is_expected.to include(finding_2) }

    it { is_expected.not_to include(finding_1) }
  end

  describe '.fix_available' do
    let_it_be(:finding_with_remediation_without_solution) do
      create(:security_finding, :with_finding_data, solution: '',
        remediation_byte_offsets: [{ "end_byte" => 2, "start_byte" => 1 }])
    end

    let_it_be(:finding_without_remediation_with_solution) do
      create(:security_finding, :with_finding_data, remediation_byte_offsets: [])
    end

    let_it_be(:finding_without_remediation_without_solution) do
      create(:security_finding, :with_finding_data, remediation_byte_offsets: [], solution: '')
    end

    subject { described_class.fix_available }

    it do
      is_expected.to contain_exactly(
        finding_1,
        finding_2,
        finding_with_remediation_without_solution,
        finding_without_remediation_with_solution
      )
    end
  end

  describe '.no_fix_available' do
    let_it_be(:finding_with_solution_without_remediation) do
      create(:security_finding, :with_finding_data, remediation_byte_offsets: [])
    end

    let_it_be(:finding_with_remediation_without_solution) do
      create(:security_finding,
        :with_finding_data,
        solution: '', remediation_byte_offsets: [{ "end_byte" => 1, "start_byte" => 2 }]
      )
    end

    let_it_be(:finding_without_remediation_without_solution) do
      create(:security_finding, :with_finding_data, solution: '', remediation_byte_offsets: [])
    end

    subject { described_class.no_fix_available }

    it { is_expected.to contain_exactly(finding_without_remediation_without_solution) }
  end

  describe '.count_by_scan_type' do
    subject { described_class.count_by_scan_type }

    let_it_be(:finding_3) { create(:security_finding, :with_finding_data, scan: scan_1) }

    it do
      is_expected.to eq({
        'dast' => 1,
        'sast' => 2
      })
    end
  end

  describe '.latest_by_uuid' do
    subject { described_class.latest_by_uuid(finding_1.uuid) }

    let_it_be(:newer_scan) { create(:security_scan, :latest_successful, scan_type: :sast) }
    let_it_be(:newer_finding) { create(:security_finding, :with_finding_data, uuid: finding_1.uuid, scan: newer_scan) }

    it { is_expected.to eq(newer_finding) }
  end

  describe '.partition_full?' do
    using RSpec::Parameterized::TableSyntax

    where(:partition_size, :considered_full?) do
      101.gigabytes     | true
      100.gigabytes     | true
      (100.gigabytes - 1) | false
    end

    with_them do
      let(:mock_partition) do
        instance_double(Gitlab::Database::Partitioning::SingleNumericListPartition, data_size: partition_size)
      end

      subject { described_class.partition_full?(mock_partition) }

      it { is_expected.to eq(considered_full?) }
    end
  end

  describe '.oldest_record_stale?' do
    let(:partition_number) { 1 }
    let(:mock_partition) do
      instance_double(Gitlab::Database::Partitioning::SingleNumericListPartition, value: partition_number)
    end

    subject { described_class.oldest_record_stale?(mock_partition) }

    context 'when there are no records in the partition' do
      it { is_expected.to be_falsey }
    end

    context 'when there are records in the partition' do
      let!(:findings) do
        create_list(:security_finding, 3, :with_finding_data, partition_number: partition_number)
      end

      context 'when the oldest record is stale' do
        before do
          described_class.oldest_record_in_partition(mock_partition)
            .scan
            .update!(created_at: Security::Scan.stale_after.ago - 1.day)
        end

        it { is_expected.to be_truthy }
      end

      context 'when the oldest record is not stale' do
        it { is_expected.to be_falsey }
      end
    end
  end

  describe 'partitioning next_partition_if condition' do
    let(:partition_number) { 1 }
    let(:mock_partition) do
      instance_double(
        Gitlab::Database::Partitioning::SingleNumericListPartition,
        value: partition_number,
        data_size: partition_size
      )
    end

    let!(:findings) do
      create_list(:security_finding, 3, :with_finding_data, partition_number: partition_number)
    end

    let(:partition_size) { 50.gigabytes }

    subject(:should_create_partition) do
      described_class.partitioning_strategy.next_partition_if.call(mock_partition)
    end

    context 'when partition is full but oldest record is not stale' do
      let(:partition_size) { 101.gigabytes }

      it { is_expected.to be_truthy }
    end

    context 'when partition is not full but oldest record is stale' do
      let(:partition_size) { 50.gigabytes }

      before do
        described_class.oldest_record_in_partition(mock_partition)
          .scan
          .update!(created_at: Security::Scan.stale_after.ago - 1.day)
      end

      it { is_expected.to be_truthy }
    end

    context 'when both partition is full and oldest record is stale' do
      let(:partition_size) { 101.gigabytes }

      before do
        described_class.oldest_record_in_partition(mock_partition)
          .scan
          .update!(created_at: Security::Scan.stale_after.ago - 1.day)
      end

      it { is_expected.to be_truthy }
    end

    context 'when partition is not full and oldest record is not stale' do
      let(:partition_size) { 50.gigabytes }

      it { is_expected.to be_falsey }
    end
  end

  describe '.detach_partition?' do
    subject { described_class.detach_partition?(partition_number) }

    context 'when there is no finding for the given partition number' do
      let(:partition_number) { 0 }

      it { is_expected.to be_falsey }
    end

    context 'when the partition is not empty' do
      let(:partition_number) { finding_2.partition_number }

      before do
        allow_next_found_instance_of(Security::Scan) do |scan|
          allow(scan).to receive(:findings_can_be_purged?).and_return(findings_can_be_purged?)
        end
      end

      context 'when the scan of last finding in partition returns false to findings_can_be_purged? message' do
        let(:findings_can_be_purged?) { false }

        it { is_expected.to be_falsey }
      end

      context 'when the scan of last finding in partition returns true to findings_can_be_purged? message' do
        let(:findings_can_be_purged?) { true }

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '.active_partition_number' do
    subject(:active_partition_number) { described_class.active_partition_number }

    it 'enforces that the sec database connection is use to retrive partition number' do
      expect(Gitlab::Database::SharedModel).to receive(:using_connection).with(::SecApplicationRecord.connection)
        .and_call_original

      active_partition_number
    end

    context 'when the `security_findings` is partitioned' do
      let(:expected_partition_number) { 9999 }

      before do
        allow_next_instance_of(Gitlab::Database::Partitioning::SingleNumericListPartition) do |partition|
          allow(partition).to receive(:value).and_return(expected_partition_number)
        end
      end

      it { is_expected.to match(expected_partition_number) }
    end

    context 'when the `security_findings` is not partitioned' do
      before do
        described_class.partitioning_strategy.current_partitions.each do |partition|
          ApplicationRecord.connection.execute(partition.to_detach_sql)
        end
      end

      it { is_expected.to match(1) }
    end
  end

  describe '.distinct_uuids' do
    it 'returns distinct uuids of findings' do
      create(:security_finding, :with_finding_data, uuid: finding_1.uuid)

      expect(described_class.distinct_context_aware_uuids).to contain_exactly(finding_1.uuid, finding_2.uuid)
    end
  end

  describe '.distinct_by_uuid' do
    let_it_be(:scan_a) { create(:security_scan, :latest_successful, scan_type: :sast) }
    let_it_be(:scan_b) { create(:security_scan, :latest_successful, scan_type: :sast) }
    let_it_be(:uuid) { SecureRandom.uuid }
    let_it_be(:finding_a) { create(:security_finding, :with_finding_data, uuid: uuid, scan: scan_a) }
    let_it_be(:finding_b) { create(:security_finding, :with_finding_data, uuid: uuid, scan: scan_b) }
    let_it_be(:finding_c) { create(:security_finding, :with_finding_data, scan: scan_a) }

    it 'returns one finding per unique uuid' do
      result = described_class.by_uuid([uuid, finding_c.uuid]).distinct_by_uuid.order(:uuid).load

      expect(result.map(&:uuid)).to contain_exactly(uuid, finding_c.uuid)
    end
  end

  describe '.except_scanners' do
    it 'returns findings except the ones associated to scanners as parameter' do
      expect(described_class.except_scanners(finding_1.scanner)).to contain_exactly(finding_2)
    end
  end

  describe '.with_finding_enrichments' do
    let_it_be(:finding_with_enrichment) do
      create(:security_finding, :with_finding_data, scan: scan_1).tap do |finding|
        create(:security_finding_enrichment, finding_uuid: finding.uuid)
      end
    end

    subject(:findings) { described_class.with_finding_enrichments }

    it 'eager loads finding enrichments' do
      expect do
        findings.each do |f|
          f.finding_enrichments.each(&:id)
        end
      end.not_to exceed_query_limit(2)
    end
  end

  describe '.with_cve_enrichment_filters' do
    let_it_be(:pm_cve_enrichment) { create(:pm_cve_enrichment) }

    let_it_be(:record_with_enrichment) do
      create(:security_finding, :with_finding_data, scan: scan_1).tap do |finding|
        create(:security_finding_enrichment, finding_uuid: finding.uuid,
          cve_enrichment_id: pm_cve_enrichment.id, epss_score: 0.75, is_known_exploit: true)
      end
    end

    let_it_be(:record_with_enrichment_no_exploit) do
      create(:security_finding, :with_finding_data, scan: scan_1).tap do |finding|
        create(:security_finding_enrichment, finding_uuid: finding.uuid,
          cve_enrichment_id: pm_cve_enrichment.id, epss_score: 0.30, is_known_exploit: false)
      end
    end

    let_it_be(:record_without_enrichment) do
      create(:security_finding, :with_finding_data, scan: scan_1)
    end

    let_it_be(:record_with_unenriched_cves) do
      create(:security_finding, :with_finding_data, scan: scan_1).tap do |finding|
        create(:security_finding_enrichment, finding_uuid: finding.uuid, cve_enrichment_id: nil)
      end
    end

    it_behaves_like 'CVE enrichment filters model spec'
  end

  describe '#state' do
    subject { finding_1.state }

    context 'when there is no associated vulnerability' do
      context 'when there is no associated dismissal feedback' do
        it { is_expected.to eq('detected') }
      end

      context 'when there is an associated dismissal feedback' do
        before do
          create(:vulnerability_feedback, :dismissal, finding_uuid: finding_1.uuid)
        end

        it { is_expected.to eq('dismissed') }
      end
    end

    context 'when there is an associated vulnerability' do
      where(:state) { %i[detected confirmed dismissed resolved] }

      before do
        create(:vulnerabilities_finding, state, uuid: finding_1.uuid)
      end

      with_them { it { is_expected.to eq(state.to_s) } }
    end
  end

  describe '#severity' do
    let_it_be_with_reload(:finding) { create(:security_finding, severity: :low) }

    subject(:severity) { finding.severity }

    it 'returns the finding severity' do
      expect(severity).to eq('low')
    end

    context 'when there is an associated vulnerability' do
      let_it_be(:vulnerability) do
        vulnerability_finding = create(:vulnerabilities_finding, severity: :critical, uuid: finding.uuid)
        create(:vulnerability, severity: :critical, findings: [vulnerability_finding])
      end

      it 'returns the severity from the security_finding record' do
        expect(severity).to eq('low')
      end

      context 'when there is a severity override' do
        let_it_be(:override) do
          create(
            :vulnerability_severity_override,
            vulnerability: vulnerability,
            original_severity: :low,
            new_severity: :critical
          )
        end

        it 'returns the vulnerability severity' do
          expect(severity).to eq('critical')
        end
      end
    end
  end

  describe 'feedback accessors' do
    shared_examples_for 'has feedback method for' do |type|
      context 'when there is no associated dismissal feedback' do
        it { is_expected.to be_nil }
      end

      context 'when there is an associated dismissal feedback' do
        let!(:feedback) { create(:vulnerability_feedback, type, finding_uuid: finding_1.uuid) }

        it { is_expected.to eq(feedback) }
      end
    end

    describe '#dismissal_feedback' do
      it_behaves_like 'has feedback method for', :dismissal do
        subject { finding_1.dismissal_feedback }
      end
    end

    describe '#issue_feedback' do
      it_behaves_like 'has feedback method for', :issue do
        subject { finding_1.issue_feedback }
      end
    end

    describe '#merge_request_feedback' do
      it_behaves_like 'has feedback method for', :merge_request do
        subject { finding_1.merge_request_feedback }
      end
    end
  end

  describe 'attributes delegated to `finding_data`' do
    using RSpec::Parameterized::TableSyntax

    where(:attribute, :expected_value) do
      :name                     | 'Test finding'
      :description              | 'Test description'
      :solution                 | 'Test solution'
      :location                 | 'Test location'
      :identifiers              | ['Test identifier']
      :links                    | ['Test link']
      :false_positive?          | false
      :assets                   | ['Test asset']
      :evidence                 | {}
      :details                  | []
      :remediation_byte_offsets | { start_byte: 0, end_byte: 1 }
      :raw_source_code_extract  | 'AES/ECB/NoPadding'
    end

    with_them do
      let(:finding) { build(:security_finding, :with_finding_data) }

      subject { finding.send(attribute) }

      before do
        finding.finding_data[attribute] = expected_value
      end

      it { is_expected.to eq(expected_value) }
    end
  end

  describe 'finding_details delegated to `finding_data` details' do
    let(:finding) { build(:security_finding, :with_finding_data) }

    subject { finding.finding_details }

    before do
      finding.finding_data['details'] = [{ name: 'Test Detail' }]
    end

    it { is_expected.to eq([{ name: 'Test Detail' }]) }
  end

  describe '#remediations', :aggregate_failures do
    let(:finding) { create(:security_finding, finding_data: finding_data) }
    let(:mock_remediations) { [Object.new] }
    let(:mock_proxy) { instance_double(Security::RemediationsProxy, by_byte_offsets: mock_remediations) }

    subject(:remediations) { finding.remediations }

    before do
      allow(finding.scan).to receive(:remediations_proxy).and_return(mock_proxy)
    end

    context 'when the remediation byte offsets do not exist' do
      let(:finding_data) { {} }

      it 'does not call the proxy and returns an empty array' do
        expect(remediations).to be_empty
        expect(mock_proxy).not_to have_received(:by_byte_offsets)
      end
    end

    context 'when the remediation byte offsets exist' do
      let(:finding_data) { { remediation_byte_offsets: [{ start_byte: 0, end_byte: 10 }] } }

      it 'delegates the call to the proxy' do
        expect(remediations).to eq(mock_remediations)
        expect(mock_proxy).to have_received(:by_byte_offsets)
      end
    end
  end

  describe '#token_type' do
    it 'returns gitleaks_rule_id external_id when present' do
      finding = create(:security_finding, :with_finding_data,
        identifiers: [{ external_type: 'gitleaks_rule_id', external_id: 'AWS' }])

      expect(finding.token_type).to eq('AWS')
    end

    it 'returns nil when gitleaks_rule_id not present' do
      finding = create(:security_finding, :with_finding_data)

      expect(finding.token_type).to be_nil
    end
  end

  describe '#token_value' do
    it 'returns raw_source_code_extract from finding_data' do
      finding = create(:security_finding, :with_finding_data)

      expect(finding.token_value).to eq('AES/ECB/NoPadding')
    end

    it 'returns nil when raw_source_code_extract not present' do
      finding = create(:security_finding, :with_finding_data,
        finding_data: { name: 'Test' })

      expect(finding.token_value).to be_nil
    end
  end

  describe '#sha' do
    let_it_be(:pipeline) { create(:ee_ci_pipeline, sha: 'pipeline_sha_abc123') }
    let_it_be(:secret_detection_scan) do
      create(:security_scan, :latest_successful, scan_type: :secret_detection, pipeline: pipeline)
    end

    subject(:sha) { finding.sha }

    context 'when the finding is not a secret detection finding' do
      let(:finding) { create(:security_finding, :with_finding_data, scan: scan_1) }

      it 'returns the pipeline SHA' do
        expect(sha).to eq(finding.pipeline.sha)
      end
    end

    context 'when the finding is a secret detection finding' do
      context 'when location contains a commit SHA' do
        let(:finding) do
          create(:security_finding, :with_finding_data, scan: secret_detection_scan,
            location: { commit: { sha: 'historic_commit_sha_def456' } })
        end

        it 'returns the commit SHA from location' do
          expect(sha).to eq('historic_commit_sha_def456')
        end
      end

      context 'when location contains the placeholder SHA' do
        let(:finding) do
          create(:security_finding, :with_finding_data, scan: secret_detection_scan,
            location: { commit: { sha: ::Vulnerabilities::Finding::SECRET_DETECTION_DEFAULT_COMMIT_SHA } })
        end

        it 'falls back to the pipeline SHA' do
          expect(sha).to eq(pipeline.sha)
        end
      end

      context 'when location does not contain a commit SHA' do
        let(:finding) do
          create(:security_finding, :with_finding_data, scan: secret_detection_scan,
            location: { file: 'config/secrets.yml' })
        end

        it 'falls back to the pipeline SHA' do
          expect(sha).to eq(pipeline.sha)
        end
      end

      context 'when location is not provided' do
        let(:finding) do
          create(:security_finding, :with_finding_data, scan: secret_detection_scan)
        end

        it 'falls back to the pipeline SHA' do
          expect(sha).to eq(pipeline.sha)
        end
      end
    end
  end

  describe '#cwe_name' do
    it 'returns true if finding has a CWE identifier' do
      finding = build(:security_finding, :with_finding_data)

      expect(finding.cwe_name).to eq 'CWE-259'
    end

    it 'returns false if finding has no CWE identifier' do
      finding = build(:security_finding, :with_finding_data)
      finding.finding_data['identifiers'] = []

      expect(finding.cwe_name).to be_nil
    end
  end

  describe '#cve_or_cwe' do
    subject(:cve_or_cwe) { finding.cve_or_cwe }

    context 'when finding has a CVE identifier' do
      let(:finding) do
        build(:security_finding, :with_finding_data,
          identifiers: [{ external_type: 'cve', name: 'CVE-2024-1234', url: 'https://example.com' }])
      end

      it 'returns the CVE identifier' do
        expect(cve_or_cwe[:name]).to eq('CVE-2024-1234')
      end
    end

    context 'when finding has only a CWE identifier' do
      let(:finding) do
        build(:security_finding, :with_finding_data,
          identifiers: [{ external_type: 'cwe', name: 'CWE-79', url: 'https://example.com' }])
      end

      it 'returns the CWE identifier' do
        expect(cve_or_cwe[:name]).to eq('CWE-79')
      end
    end

    context 'when finding has both CVE and CWE identifiers' do
      let(:finding) do
        build(:security_finding, :with_finding_data,
          identifiers: [
            { external_type: 'cwe', name: 'CWE-79', url: 'https://example.com' },
            { external_type: 'cve', name: 'CVE-2024-1234', url: 'https://example.com' }
          ])
      end

      it 'returns the CVE identifier' do
        expect(cve_or_cwe[:name]).to eq('CVE-2024-1234')
      end
    end

    context 'when finding has no CVE or CWE identifier' do
      let(:finding) do
        build(:security_finding, :with_finding_data,
          identifiers: [{ external_type: 'other', name: 'OTHER-123', url: 'https://example.com' }])
      end

      it 'returns nil' do
        expect(cve_or_cwe).to be_nil
      end
    end

    context 'when finding has identifier with nil external_type' do
      let(:finding) do
        build(:security_finding, :with_finding_data,
          identifiers: [{ external_type: nil, name: 'NULL-TYPE', url: 'https://example.com' }])
      end

      it 'returns nil' do
        expect(cve_or_cwe).to be_nil
      end
    end
  end

  describe '#ai_resolution_available?' do
    it 'returns true if the finding is a SAST finding' do
      expect(finding_1.ai_resolution_available?).to be true
    end

    it 'returns false if the finding is not a SAST finding' do
      expect(finding_2.ai_resolution_available?).to be false
    end
  end

  describe '#ai_resolution_enabled?' do
    using RSpec::Parameterized::TableSyntax
    let(:finding) { build(:security_finding, :with_finding_data) }

    where(:finding_report_type, :cwe, :enabled_value) do
      'sast' | 'CWE-1'  | false
      'sast' | 'CWE-23' | true
      'dast' | 'CWE-1'  | false
      'dast' | 'CWE-23' | false
    end

    with_them do
      it 'returns the expected value for enabled' do
        finding.scan.scan_type = finding_report_type
        finding.finding_data["identifiers"] = [build(:ci_reports_security_identifier, :cwe, name: cwe).to_hash]
        expect(finding.ai_resolution_enabled?).to be enabled_value
      end
    end
  end

  describe '#file' do
    subject(:file) { finding.file }

    context 'when location has file key' do
      let(:finding) do
        create(:security_finding, :with_finding_data, location: { file: 'src/main.rb' })
      end

      it { is_expected.to eq('src/main.rb') }
    end

    context 'when location does not have file key' do
      let(:finding) do
        create(:security_finding, :with_finding_data, location: { report_type: 'coverage_fuzzing' })
      end

      it { is_expected.to be_nil }
    end

    context 'when location is empty' do
      let(:finding) do
        create(:security_finding, :with_finding_data, location: {})
      end

      it { is_expected.to be_nil }
    end

    context 'when location is nil' do
      let(:finding) do
        create(:security_finding, location: nil)
      end

      it { is_expected.to be_nil }
    end
  end

  it_behaves_like 'policy auto-dismissable' do
    let_it_be(:policy_rule_attributes) { { file_path: 'test/**/*' } }
    let_it_be(:scan) { create(:security_scan, project: project) }

    let!(:matching_finding) do
      create(:security_finding, :with_finding_data, scan: scan, location: { file: 'test/spec/example_spec.rb' })
    end

    let!(:non_matching_finding) do
      create(:security_finding, :with_finding_data, scan: scan, location: { file: 'src/main.c' })
    end
  end

  it_behaves_like 'policy severity overridable' do
    let_it_be(:policy_rule_attributes) { { file_path: 'test/**/*' } }
    let_it_be(:scan) { create(:security_scan, project: project) }

    let!(:matching_finding) do
      create(:security_finding, :with_finding_data, scan: scan, severity: :low,
        location: { file: 'test/spec/example_spec.rb' })
    end

    let!(:non_matching_finding) do
      create(:security_finding, :with_finding_data, scan: scan, severity: :low,
        location: { file: 'src/main.c' })
    end
  end
end
