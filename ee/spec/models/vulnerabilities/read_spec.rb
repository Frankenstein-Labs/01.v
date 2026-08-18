# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Read, type: :model, feature_category: :vulnerability_management do
  let_it_be_with_reload(:project) { create(:project) }

  it_behaves_like 'vulnerability and finding shared examples' do
    let(:transformer_method) { :vulnerability_read }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:vulnerability) }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:scanner).class_name('Vulnerabilities::Scanner') }
    it { is_expected.to belong_to(:tracked_context).class_name('Security::ProjectTrackedContext') }
  end

  describe 'validations' do
    let!(:vulnerability_read) { create(:vulnerability_read, project: project) }

    it { is_expected.to validate_presence_of(:vulnerability_id) }
    it { is_expected.to validate_presence_of(:project_id) }
    it { is_expected.to validate_presence_of(:scanner_id) }
    it { is_expected.to validate_presence_of(:report_type) }
    it { is_expected.to validate_presence_of(:severity) }
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_presence_of(:uuid) }
    it { is_expected.to validate_length_of(:location_image).is_at_most(2048) }

    it { is_expected.to validate_uniqueness_of(:vulnerability_id) }
  end

  describe 'triggers' do
    let_it_be(:user) { create(:user) }
    let(:issue) { create(:issue, project: project) }
    let(:scanner) { create(:vulnerabilities_scanner, project: project) }
    let(:identifier) { create(:vulnerabilities_identifier, project: project) }
    let(:vulnerability) { create_vulnerability }
    let(:vulnerability2) { create_vulnerability }
    let(:finding) { create_finding(primary_identifier: identifier) }

    describe 'trigger on vulnerability_occurrences insert' do
      context 'when vulnerability_id is set' do
        subject(:create_finding_record) { create_finding(vulnerability: vulnerability2) }

        let(:created_vulnerability_read) { described_class.find_by_vulnerability_id(vulnerability2.id) }

        context 'when the related vulnerability record is not marked as `present_on_default_branch`' do
          before do
            vulnerability2.update_column(:present_on_default_branch, false)
          end

          it 'does not create a new vulnerability_reads row' do
            expect { create_finding_record }.not_to change { Vulnerabilities::Read.count }
          end
        end

        context 'when the related vulnerability record is marked as `present_on_default_branch`' do
          it 'creates a new vulnerability_reads row' do
            expect { create_finding_record }.to change { Vulnerabilities::Read.count }.from(0).to(1)
            expect(created_vulnerability_read.has_issues).to be(false)
            expect(created_vulnerability_read.has_merge_request).to be(false)
          end

          it 'sets has_issues to true when there are issue links' do
            create(:vulnerabilities_issue_link, vulnerability: vulnerability2)
            create_finding_record
            expect(created_vulnerability_read.has_issues).to be(true)
          end

          it 'sets has_merge_request to true when there are merge request links' do
            create(:vulnerabilities_merge_request_link, vulnerability: vulnerability2)
            create_finding_record
            expect(created_vulnerability_read.has_merge_request).to be(true)
          end
        end
      end

      context 'when vulnerability_id is not set' do
        it 'does not create a new vulnerability_reads row' do
          expect do
            create_finding
          end.not_to change { Vulnerabilities::Read.count }
        end
      end
    end

    describe 'trigger on vulnerability_occurrences update' do
      let(:created_vulnerability_read) { described_class.find_by_vulnerability_id(vulnerability.id) }

      context 'when vulnerability_id is updated' do
        it 'creates a new vulnerability_reads row' do
          expect do
            finding.update!(vulnerability_id: vulnerability.id)
          end.to change { Vulnerabilities::Read.count }.from(0).to(1)

          expect(created_vulnerability_read.has_issues).to be(false)

          expect(created_vulnerability_read.has_merge_request).to be(false)
        end

        it 'sets has_issues when the vulnerability has issue links' do
          create(:vulnerabilities_issue_link, vulnerability: vulnerability)
          finding.update!(vulnerability_id: vulnerability.id)
          expect(created_vulnerability_read.has_issues).to be(true)
        end

        it 'sets has_merge_request when the vulnerability has merge request links' do
          create(:vulnerabilities_merge_request_link, vulnerability: vulnerability)
          finding.update!(vulnerability_id: vulnerability.id)
          expect(created_vulnerability_read.has_merge_request).to be(true)
        end
      end

      context 'when vulnerability_id is not updated' do
        it 'does not create a new vulnerability_reads row' do
          finding.update!(vulnerability_id: nil)

          expect do
            finding.update!(location: '')
          end.not_to change { Vulnerabilities::Read.count }
        end
      end
    end

    describe 'trigger on vulnerability_occurrences location update' do
      let!(:cluster_agent) { create(:cluster_agent, project: project) }

      context 'when image is updated' do
        it 'updates location_image in vulnerability_reads' do
          finding = create_finding(vulnerability: vulnerability, report_type: 7, location: { "image" => "alpine:3.4" })

          expect do
            finding.update!(location: { "image" => "alpine:4" })
          end.to change { Vulnerabilities::Read.first.location_image }.from("alpine:3.4").to("alpine:4")
        end
      end

      context 'when agent_id is updated' do
        it 'updates cluster_agent_id in vulnerability_reads' do
          finding = create_finding(vulnerability: vulnerability, report_type: 7, location: { "image" => "alpine:3.4" })

          expect do
            finding.update!(location: { "kubernetes_resource" => { "agent_id" => cluster_agent.id.to_s } })
          end.to change { Vulnerabilities::Read.first.cluster_agent_id }.from(nil).to(cluster_agent.id.to_s)
        end
      end

      context 'when image or agent_id is not updated' do
        it 'does not update location_image or cluster_agent_id in vulnerability_reads' do
          finding = create_finding(
            vulnerability: vulnerability,
            report_type: 7,
            location: { "image" => "alpine:3.4", "kubernetes_resource" => { "agent_id" => cluster_agent.id.to_s } }
          )

          expect do
            finding.update!(uuid: SecureRandom.uuid)
          end.not_to change { Vulnerabilities::Read.first.location_image }
        end
      end
    end

    describe 'trigger on vulnerabilities update' do
      before do
        create_finding(vulnerability: vulnerability, report_type: 7)
      end

      context 'when the vulnerability is not marked as `present_on_default_branch`' do
        before do
          vulnerability.update_column(:present_on_default_branch, false)
        end

        it 'does not update vulnerability attributes in vulnerability_reads' do
          expect { vulnerability.update!(severity: :high) }.not_to change { Vulnerabilities::Read.first.severity }.from('critical')
        end
      end

      context 'when the vulnerability is marked as `present_on_default_branch`' do
        context 'when vulnerability attributes are updated' do
          it 'updates vulnerability attributes in vulnerability_reads' do
            expect do
              vulnerability.update!(severity: :high)
            end.to change { Vulnerabilities::Read.first.severity }.from("critical").to("high")
          end
        end

        context 'when vulnerability attributes are not updated' do
          it 'does not update vulnerability attributes in vulnerability_reads' do
            expect do
              vulnerability.update!(title: "New vulnerability")
            end.not_to change { Vulnerabilities::Read.first }
          end
        end
      end
    end

    describe 'trigger_insert_vulnerability_reads_from_vulnerability' do
      subject(:update_vulnerability) { vulnerability.update!(new_vulnerability_params) }

      let(:created_vulnerability_read) { described_class.find_by_vulnerability_id(vulnerability.id) }

      before do
        vulnerability.update_column(:present_on_default_branch, false)

        create_finding(vulnerability: vulnerability)
      end

      context 'when the vulnerability does not get marked as `present_on_default_branch`' do
        let(:new_vulnerability_params) { { updated_at: Time.zone.now } }

        it 'does not create a new `vulnerability_reads` record' do
          expect { update_vulnerability }.not_to change { Vulnerabilities::Read.count }
        end
      end

      context 'when the vulnerability gets marked as `present_on_default_branch`' do
        let(:new_vulnerability_params) { { present_on_default_branch: true } }

        it 'creates a new `vulnerability_reads` record' do
          expect { update_vulnerability }.to change { Vulnerabilities::Read.count }.by(1)
          expect(created_vulnerability_read.has_issues).to be(false)
          expect(created_vulnerability_read.has_merge_request).to be(false)
        end

        it 'sets has_issues when the created vulnerability has issue links' do
          create(:vulnerabilities_issue_link, vulnerability: vulnerability)
          update_vulnerability
          expect(created_vulnerability_read.has_issues).to be(true)
        end

        it 'sets has_merge_request when the created vulnerability has merge request links' do
          create(:vulnerabilities_merge_request_link, vulnerability: vulnerability)
          update_vulnerability
          expect(created_vulnerability_read.has_merge_request).to be(true)
        end
      end
    end

    describe 'trigger on vulnerabilities_issue_link' do
      context 'on insert' do
        before do
          create_finding(vulnerability: vulnerability, report_type: 7)
        end

        it 'updates has_issues in vulnerability_reads' do
          expect do
            create(:vulnerabilities_issue_link, vulnerability: vulnerability, issue: issue)
          end.to change { Vulnerabilities::Read.first.has_issues }.from(false).to(true)
        end
      end

      context 'on delete' do
        before do
          create_finding(vulnerability: vulnerability, report_type: 7)
        end

        let(:issue2) { create(:issue, project: project) }

        it 'does not change has_issues when there exists another issue' do
          issue_link1 = create(:vulnerabilities_issue_link, vulnerability: vulnerability, issue: issue)
          create(:vulnerabilities_issue_link, vulnerability: vulnerability, issue: issue2)

          expect do
            issue_link1.delete
          end.not_to change { Vulnerabilities::Read.first.has_issues }
        end

        it 'unsets has_issues when all issues are deleted' do
          issue_link1 = create(:vulnerabilities_issue_link, vulnerability: vulnerability, issue: issue)
          issue_link2 = create(:vulnerabilities_issue_link, vulnerability: vulnerability, issue: issue2)

          expect do
            issue_link1.delete
            issue_link2.delete
          end.to change { Vulnerabilities::Read.first.has_issues }.from(true).to(false)
        end
      end
    end
  end

  describe '.es_type' do
    subject { described_class.es_type }

    it { is_expected.to eq('vulnerability') }
  end

  describe '.by_scanner_ids' do
    it 'returns matching vulnerabilities' do
      vulnerability1 = create(:vulnerability, :with_finding, project: project)
      create(:vulnerability, :with_finding, project: project)

      result = described_class.by_scanner_ids(vulnerability1.finding_scanner_id)

      expect(result).to match_array([vulnerability1.vulnerability_read])
    end
  end

  describe '.with_report_types' do
    let!(:dast_vulnerability) { create(:vulnerability, :with_finding, :dast, project: project) }
    let!(:dependency_scanning_vulnerability) { create(:vulnerability, :with_finding, :dependency_scanning, project: project) }
    let(:sast_vulnerability) { create(:vulnerability, :with_finding, :sast, project: project) }
    let(:report_types) { %w[sast dast] }

    subject { described_class.with_report_types(report_types) }

    it 'returns vulnerabilities matching the given report_types' do
      is_expected.to contain_exactly(sast_vulnerability.vulnerability_read, dast_vulnerability.vulnerability_read)
    end
  end

  describe '.with_severities' do
    let!(:high_vulnerability) { create(:vulnerability, :with_finding, :high, project: project) }
    let!(:medium_vulnerability) { create(:vulnerability, :with_finding, :medium, project: project) }
    let(:low_vulnerability) { create(:vulnerability, :with_finding, :low, project: project) }
    let(:severities) { %w[medium low] }

    subject { described_class.with_severities(severities) }

    it 'returns vulnerabilities matching the given severities' do
      is_expected.to contain_exactly(medium_vulnerability.vulnerability_read, low_vulnerability.vulnerability_read)
    end
  end

  describe '.with_states' do
    let!(:detected_vulnerability) { create(:vulnerability, :with_finding, :detected, project: project) }
    let!(:dismissed_vulnerability) { create(:vulnerability, :with_finding, :dismissed, project: project) }
    let(:confirmed_vulnerability) { create(:vulnerability, :with_finding, :confirmed, project: project) }
    let(:states) { %w[detected confirmed] }

    subject { described_class.with_states(states) }

    it 'returns vulnerabilities matching the given states' do
      is_expected.to contain_exactly(detected_vulnerability.vulnerability_read, confirmed_vulnerability.vulnerability_read)
    end
  end

  describe '.with_owasp_top_10' do
    let_it_be(:owasp_top_10_value) { 'A1:2021-Broken Access Control' }

    subject(:with_owasp_top_10) { described_class.with_owasp_top_10(owasp_top_10_value) }

    context 'when owasp_top_10 record exists' do
      let_it_be(:vuln_read_with_owasp_top_10) { create(:vulnerability_read, owasp_top_10: owasp_top_10_value, project: project) }

      it { expect(with_owasp_top_10).to contain_exactly(vuln_read_with_owasp_top_10) }
    end

    context 'when owasp_top_10 is nil' do
      let_it_be(:vuln_read_with_nil_owasp_top_10) { create(:vulnerability_read, owasp_top_10: nil, project: project) }
      let_it_be(:owasp_top_10_value) { nil }

      it { expect(with_owasp_top_10).to contain_exactly(vuln_read_with_nil_owasp_top_10) }
    end

    context 'without owasp_top_10' do
      let_it_be(:vuln_read_without_owasp_top_10) { create(:vulnerability_read, project: project) }

      it { expect(with_owasp_top_10).to be_empty }
    end
  end

  describe '.with_identifier_names' do
    let_it_be(:vulnerability_read_with_identifier) do
      create(:vulnerability_read, :with_identifer_name, identifier_names: ['CVE-2018-1234'], project: project)
    end

    let_it_be(:vulnerability_read_with_different_identifier) do
      create(:vulnerability_read, :with_identifer_name, identifier_names: ['CVE-2019-5678'], project: project)
    end

    let_it_be(:vulnerability_read_without_identifier) { create(:vulnerability_read, project: project) }

    subject(:vulnerability_reads) { described_class.with_identifier_name(identifier_name) }

    context 'when a matching identifier exists' do
      let(:identifier_name) { vulnerability_read_with_different_identifier.identifier_names.first }

      it { is_expected.to contain_exactly(vulnerability_read_with_different_identifier) }
    end

    context 'when no matching identifier exists' do
      let(:identifier_name) { 'CVE-2020-9999' }

      it { is_expected.to be_empty }
    end

    context 'when identifier name is nil' do
      let(:identifier_name) { nil }

      it { is_expected.to be_empty }
    end
  end

  describe '.with_scanner_external_ids' do
    let!(:vulnerability_1) { create(:vulnerability, :with_finding, project: project) }
    let!(:vulnerability_2) { create(:vulnerability, :with_finding, project: project) }
    let(:vulnerability_3) { create(:vulnerability, :with_finding, project: project) }
    let(:scanner_external_ids) { [vulnerability_1.finding_scanner_external_id, vulnerability_3.finding_scanner_external_id] }

    subject { described_class.with_scanner_external_ids(scanner_external_ids) }

    it 'returns vulnerabilities matching the given scanner external IDs' do
      is_expected.to contain_exactly(vulnerability_1.vulnerability_read, vulnerability_3.vulnerability_read)
    end
  end

  describe 'avoid N+1 sql queries' do
    let!(:scanner) { create(:vulnerabilities_scanner, project: project) }
    let!(:identifier) { create(:vulnerabilities_identifier, project: project) }
    let!(:vulnerability) { create(:vulnerability, project: project) }
    let!(:finding) { create_finding(vulnerability: vulnerability, primary_identifier: identifier) }

    subject { described_class.new }

    it '.with_findings_scanner_and_identifiers' do
      recorder = ActiveRecord::QueryRecorder.new do
        described_class.with_findings_scanner_and_identifiers.to_a
      end

      expect(recorder.count).to eq(5)
    end

    it '.with_export_entities' do
      recorder = ActiveRecord::QueryRecorder.new do
        described_class.with_export_entities.to_a
      end

      expect(recorder.count).to eq(9)
    end

    # Generate test for the scope preload_for_es_indexing
    it '.preload_indexing_data' do
      recorder = ActiveRecord::QueryRecorder.new do
        described_class.preload_indexing_data.find_by_vulnerability_id(vulnerability)
      end

      expect(recorder.count).to eq(5)
    end
  end

  describe '.with_container_image' do
    let_it_be_with_reload(:vulnerability) { create(:vulnerability, project: project, report_type: 'cluster_image_scanning') }
    let_it_be_with_reload(:finding) { create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata, project: project, vulnerability: vulnerability) }

    let_it_be(:vulnerability_with_different_image) { create(:vulnerability, project: project, report_type: 'cluster_image_scanning') }
    let_it_be(:finding_with_different_image) do
      create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata,
        project: project, vulnerability: vulnerability_with_different_image, location_image: 'alpine:latest')
    end

    let_it_be(:image) { finding.location['image'] }

    subject(:cluster_vulnerabilities) { described_class.with_container_image(image) }

    it 'returns vulnerabilities with given image' do
      expect(cluster_vulnerabilities).to contain_exactly(vulnerability.vulnerability_read)
    end
  end

  describe '.with_container_image_starting_with' do
    let_it_be_with_reload(:vulnerability) { create(:vulnerability, project: project, report_type: 'cluster_image_scanning') }
    let_it_be_with_reload(:finding) { create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata, project: project, vulnerability: vulnerability) }

    let_it_be(:vulnerability_with_different_image) { create(:vulnerability, project: project, report_type: 'cluster_image_scanning') }
    let_it_be(:finding_with_different_image) do
      create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata,
        project: project, vulnerability: vulnerability_with_different_image, location_image: 'alpine:latest')
    end

    let_it_be(:image) { finding.location['image'][0, 10] }

    subject(:cluster_vulnerabilities) { described_class.with_container_image_starting_with(image) }

    it 'returns vulnerabilities with given image' do
      expect(cluster_vulnerabilities).to contain_exactly(vulnerability.vulnerability_read)
    end
  end

  describe '.with_resolution' do
    let_it_be(:vulnerability_with_resolution) { create(:vulnerability, :with_finding, resolved_on_default_branch: true, project: project) }
    let_it_be(:vulnerability_without_resolution) { create(:vulnerability, :with_finding, resolved_on_default_branch: false, project: project) }

    subject { described_class.with_resolution(with_resolution) }

    context 'when no argument is provided' do
      subject { described_class.with_resolution }

      it { is_expected.to match_array([vulnerability_with_resolution.vulnerability_read]) }
    end

    context 'when the argument is provided' do
      context 'when the given argument is `true`' do
        let(:with_resolution) { true }

        it { is_expected.to match_array([vulnerability_with_resolution.vulnerability_read]) }
      end

      context 'when the given argument is `false`' do
        let(:with_resolution) { false }

        it { is_expected.to match_array([vulnerability_without_resolution.vulnerability_read]) }
      end
    end
  end

  describe '.with_ai_resolution' do
    subject { described_class.with_ai_resolution(with_resolution) }

    let_it_be(:read_with_ai_resolution) { create(:vulnerability_read, project: project, has_vulnerability_resolution: true) }
    let_it_be(:read_without_ai_resolution) { create(:vulnerability_read, project: project, has_vulnerability_resolution: false) }

    context 'when no argument is provided' do
      subject { described_class.with_ai_resolution }

      it { is_expected.to match_array([read_with_ai_resolution]) }
    end

    context 'when the argument is true' do
      let(:with_resolution) { true }

      it { is_expected.to match_array([read_with_ai_resolution]) }
    end

    context 'when the given argument is `false`' do
      let(:with_resolution) { false }

      it { is_expected.to match_array([read_without_ai_resolution]) }
    end
  end

  describe '.with_issues' do
    let_it_be(:vulnerability_with_issues) { create(:vulnerability, :with_finding, :with_issue_links, project: project) }
    let_it_be(:vulnerability_without_issues) { create(:vulnerability, :with_finding, project: project) }

    subject { described_class.with_issues(with_issues) }

    context 'when no argument is provided' do
      subject { described_class.with_issues }

      it { is_expected.to match_array([vulnerability_with_issues.vulnerability_read]) }
    end

    context 'when the argument is provided' do
      context 'when the given argument is `true`' do
        let(:with_issues) { true }

        it { is_expected.to match_array([vulnerability_with_issues.vulnerability_read]) }
      end

      context 'when the given argument is `false`' do
        let(:with_issues) { false }

        it { is_expected.to match_array([vulnerability_without_issues.vulnerability_read]) }
      end
    end
  end

  describe '.with_merge_request' do
    let_it_be(:vulnerability_with_merge_request) { create(:vulnerability, :with_finding, :with_merge_request_links, project: project) }
    let_it_be(:vulnerability_without_merge_request) { create(:vulnerability, :with_finding, project: project) }

    subject { described_class.with_merge_request(with_merge_request) }

    context 'when no argument is provided' do
      subject { described_class.with_merge_request }

      it { is_expected.to match_array([vulnerability_with_merge_request.vulnerability_read]) }
    end

    context 'when the argument is provided' do
      context 'when the given argument is `true`' do
        let(:with_merge_request) { true }

        it { is_expected.to match_array([vulnerability_with_merge_request.vulnerability_read]) }
      end

      context 'when the given argument is `false`' do
        let(:with_merge_request) { false }

        it { is_expected.to match_array([vulnerability_without_merge_request.vulnerability_read]) }
      end
    end
  end

  describe '.with_true_positive_ai_flag' do
    let_it_be(:matching_vulnerability) { create(:vulnerability, project: project) }
    let_it_be(:superseded_vulnerability) { create(:vulnerability, project: project) }

    before_all do
      matching_finding = create(:vulnerabilities_finding, project: project)
      create(:vulnerabilities_flag, finding: matching_finding, status: :detected_as_not_fp)
      create(:vulnerability_read, vulnerability: matching_vulnerability,
        vulnerability_occurrence: matching_finding, project: project)

      false_positive_finding = create(:vulnerabilities_finding, project: project)
      create(:vulnerabilities_flag, finding: false_positive_finding, status: :detected_as_fp)
      create(:vulnerability_read, vulnerability: create(:vulnerability, project: project),
        vulnerability_occurrence: false_positive_finding, project: project)

      # An older detected_as_not_fp flag superseded by a newer false-positive flag from another
      # origin: only the latest flag counts, so this read must be excluded.
      superseded_finding = create(:vulnerabilities_finding, project: project)
      create(:vulnerabilities_flag, finding: superseded_finding, status: :detected_as_not_fp,
        origin: 'ai_sast_fp_detection')
      create(:vulnerabilities_flag, finding: superseded_finding, status: :detected_as_fp, origin: 'scanner')
      create(:vulnerability_read, vulnerability: superseded_vulnerability,
        vulnerability_occurrence: superseded_finding, project: project)
    end

    it 'returns only reads whose latest false-positive flag is detected_as_not_fp' do
      expect(described_class.with_true_positive_ai_flag.map(&:vulnerability_id))
        .to contain_exactly(matching_vulnerability.id)
    end
  end

  describe '.with_ai_created_merge_request' do
    let_it_be(:matching_vulnerability) { create(:vulnerability, project: project) }

    before_all do
      create(:vulnerabilities_merge_request_link, vulnerability: matching_vulnerability,
        merge_request: create(:merge_request), created_by_ai_workflow: true)
      create(:vulnerability_read, vulnerability: matching_vulnerability, project: project)

      human_vulnerability = create(:vulnerability, project: project)
      create(:vulnerabilities_merge_request_link, vulnerability: human_vulnerability,
        merge_request: create(:merge_request), created_by_ai_workflow: false)
      create(:vulnerability_read, vulnerability: human_vulnerability, project: project)
    end

    it 'returns only reads whose vulnerability has an AI-workflow-created merge request link' do
      expect(described_class.with_ai_created_merge_request.map(&:vulnerability_id))
        .to contain_exactly(matching_vulnerability.id)
    end
  end

  describe '.created_between' do
    let_it_be(:matching_vulnerability) { create(:vulnerability, project: project, created_at: Date.new(2026, 3, 1)) }

    before_all do
      create(:vulnerability_read, vulnerability: matching_vulnerability, project: project)

      out_of_window_vulnerability = create(:vulnerability, project: project, created_at: Date.new(2025, 1, 1))
      create(:vulnerability_read, vulnerability: out_of_window_vulnerability, project: project)
    end

    it 'returns only reads whose vulnerability was created within the range' do
      expect(described_class.created_between(Date.new(2026, 1, 1), Date.new(2026, 6, 1)).map(&:vulnerability_id))
        .to contain_exactly(matching_vulnerability.id)
    end
  end

  describe '.as_vulnerabilities' do
    let!(:vulnerability_1) { create(:vulnerability, :with_finding, project: project) }
    let!(:vulnerability_2) { create(:vulnerability, :with_finding, project: project) }
    let!(:vulnerability_3) { create(:vulnerability, :with_finding, project: project) }

    subject { described_class.as_vulnerabilities }

    it 'returns vulnerabilities as list' do
      is_expected.to contain_exactly(vulnerability_1, vulnerability_2, vulnerability_3)
    end
  end

  describe '.count_by_severity' do
    let!(:high_severity_vulns) { create_list(:vulnerability, 2, :with_read, :high, project: project) }
    let!(:low_severity_vulns) { create_list(:vulnerability, 3, :with_read, :low, project: project) }

    subject { described_class.count_by_severity }

    it 'returns the count of vulnerabilities grouped by severity' do
      is_expected.to eq({ 'high' => high_severity_vulns.count, 'low' => low_severity_vulns.count })
    end
  end

  describe '.capped_count_by_severity' do
    let(:test_limit) { 2 }
    let(:vulnerabilities) { described_class }

    subject(:count) { vulnerabilities.capped_count_by_severity }

    before_all do
      create_list(:vulnerability, 3, :with_read, :high, :confirmed, project: project)
      create_list(:vulnerability, 1, :with_read, :low, :detected, project: project)
    end

    before do
      stub_const("#{described_class}::SEVERITY_COUNT_LIMIT", test_limit)
    end

    it { is_expected.to eq({ 'high' => test_limit, 'low' => 1 }) }

    context 'with state scope' do
      let(:vulnerabilities) { described_class.with_states([:detected]) }

      it { is_expected.to eq({ 'low' => 1 }) }
    end

    context 'with severitiy scope' do
      let(:vulnerabilities) { described_class.with_severities(:high) }

      it { is_expected.to eq({ 'high' => test_limit }) }
    end

    context 'when scope is none' do
      let(:vulnerabilities) { described_class.none }

      it { is_expected.to be_empty }
    end
  end

  describe '.order_by' do
    let_it_be(:vulnerability_1) { create(:vulnerability, :with_finding, :low, project: project) }
    let_it_be(:vulnerability_2) { create(:vulnerability, :with_finding, :critical, project: project) }
    let_it_be(:vulnerability_3) { create(:vulnerability, :with_finding, :medium, project: project) }

    subject { described_class.order_by(method) }

    context 'when method is nil' do
      let(:method) { nil }

      it { is_expected.to match_array([vulnerability_2.vulnerability_read, vulnerability_3.vulnerability_read, vulnerability_1.vulnerability_read]) }
    end

    context 'when ordered by severity_desc' do
      let(:method) { :severity_desc }

      it { is_expected.to match_array([vulnerability_2.vulnerability_read, vulnerability_3.vulnerability_read, vulnerability_1.vulnerability_read]) }
    end

    context 'when ordered by severity_asc' do
      let(:method) { :severity_asc }

      it { is_expected.to match_array([vulnerability_1.vulnerability_read, vulnerability_3.vulnerability_read, vulnerability_2.vulnerability_read]) }
    end

    context 'when ordered by detected_desc' do
      let(:method) { :detected_desc }

      it { is_expected.to match_array([vulnerability_3.vulnerability_read, vulnerability_2.vulnerability_read, vulnerability_1.vulnerability_read]) }
    end

    context 'when ordered by detected_asc' do
      let(:method) { :detected_asc }

      it { is_expected.to match_array([vulnerability_1.vulnerability_read, vulnerability_2.vulnerability_read, vulnerability_3.vulnerability_read]) }
    end
  end

  describe '.order_by_params_and_traversal_ids' do
    let_it_be(:vulnerability_1) { create(:vulnerability, :with_read, :low, project: project) }
    let_it_be(:vulnerability_2) { create(:vulnerability, :with_read, :critical, project: project) }
    let_it_be(:vulnerability_3) { create(:vulnerability, :with_read, :medium, project: project) }

    subject { described_class.order_by_params_and_traversal_ids(method) }

    context 'when method is nil' do
      let(:method) { nil }

      it { is_expected.to match_array([vulnerability_2.vulnerability_read, vulnerability_3.vulnerability_read, vulnerability_1.vulnerability_read]) }
    end

    context 'when ordered by severity_desc' do
      let(:method) { :severity_desc }

      it { is_expected.to match_array([vulnerability_2.vulnerability_read, vulnerability_3.vulnerability_read, vulnerability_1.vulnerability_read]) }
    end

    context 'when ordered by severity_asc' do
      let(:method) { :severity_asc }

      it { is_expected.to match_array([vulnerability_1.vulnerability_read, vulnerability_3.vulnerability_read, vulnerability_2.vulnerability_read]) }
    end

    context 'when ordered by detected_desc' do
      let(:method) { :detected_desc }

      it { is_expected.to match_array([vulnerability_3.vulnerability_read, vulnerability_2.vulnerability_read, vulnerability_1.vulnerability_read]) }
    end

    context 'when ordered by detected_asc' do
      let(:method) { :detected_asc }

      it { is_expected.to match_array([vulnerability_1.vulnerability_read, vulnerability_2.vulnerability_read, vulnerability_3.vulnerability_read]) }
    end
  end

  describe '.order_severity_' do
    let_it_be(:low_vulnerability) { create(:vulnerability, :with_finding, :low, project: project) }
    let_it_be(:critical_vulnerability) { create(:vulnerability, :with_finding, :critical, project: project) }
    let_it_be(:medium_vulnerability) { create(:vulnerability, :with_finding, :medium, project: project) }

    describe 'ascending' do
      subject { described_class.order_severity_asc }

      it { is_expected.to match_array([low_vulnerability.vulnerability_read, medium_vulnerability.vulnerability_read, critical_vulnerability.vulnerability_read]) }
    end

    describe 'descending' do
      subject { described_class.order_severity_desc }

      it { is_expected.to match_array([critical_vulnerability.vulnerability_read, medium_vulnerability.vulnerability_read, low_vulnerability.vulnerability_read]) }
    end
  end

  describe '.order_detected_at_' do
    let_it_be(:old_vulnerability) { create(:vulnerability, :with_finding, project: project) }
    let_it_be(:new_vulnerability) { create(:vulnerability, :with_finding, project: project) }

    describe 'ascending' do
      subject { described_class.order_detected_at_asc }

      it 'returns vulnerabilities ordered by created_at' do
        is_expected.to match_array([old_vulnerability.vulnerability_read, new_vulnerability.vulnerability_read])
      end
    end

    describe 'descending' do
      subject { described_class.order_detected_at_desc }

      it 'returns vulnerabilities ordered by created_at' do
        is_expected.to match_array([new_vulnerability.vulnerability_read, old_vulnerability.vulnerability_read])
      end
    end
  end

  describe '.container_images' do
    let_it_be_with_reload(:vulnerability) { create(:vulnerability, project: project, report_type: 'cluster_image_scanning') }
    let_it_be_with_reload(:finding) { create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata, project: project, vulnerability: vulnerability) }

    let_it_be(:vulnerability_with_different_image) { create(:vulnerability, project: project, report_type: 'cluster_image_scanning') }
    let_it_be(:finding_with_different_image) do
      create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata,
        project: project, vulnerability: vulnerability_with_different_image, location_image: 'alpine:latest')
    end

    subject(:container_images) { described_class.all.container_images }

    it 'returns container images for vulnerabilities' do
      expect(container_images.map(&:location_image)).to match_array(['alpine:3.7', 'alpine:latest'])
    end
  end

  describe '.by_scanner' do
    let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }
    let_it_be(:other_scanner) { create(:vulnerabilities_scanner, project: project) }
    let_it_be_with_reload(:finding) { create(:vulnerabilities_finding, scanner: scanner) }
    let_it_be_with_reload(:other_finding) { create(:vulnerabilities_finding, scanner: other_scanner) }
    let_it_be_with_reload(:vulnerability) { create(:vulnerability, project: project, present_on_default_branch: true, findings: [finding]) }
    let_it_be_with_reload(:vulnerability_for_another_scanner) { create(:vulnerability, project: project, present_on_default_branch: true, findings: [other_finding]) }

    subject(:vulnerability_reads) { described_class.by_scanner(scanner) }

    it 'returns records by given scanner' do
      expect(vulnerability_reads.pluck(:vulnerability_id)).to match_array([vulnerability.id])
    end
  end

  describe '.with_remediations' do
    let_it_be(:vulnerability_read_with_remediations) { create(:vulnerability_read, :with_remediations, project: project) }
    let_it_be(:vulnerability_read_without_remediations) { create(:vulnerability_read, project: project) }

    subject { described_class.with_remediations(has_remediations) }

    context 'when no argument is provided' do
      subject { described_class.with_remediations }

      it { is_expected.to match_array([vulnerability_read_with_remediations]) }
    end

    context 'when the argument is provided' do
      context 'when the given argument is `true`' do
        let(:has_remediations) { true }

        it { is_expected.to match_array([vulnerability_read_with_remediations]) }
      end

      context 'when the given argument is `false`' do
        let(:has_remediations) { false }

        it { is_expected.to match_array([vulnerability_read_without_remediations]) }
      end
    end
  end

  describe '.owasp_top_10' do
    it 'raises ArgumentError for invalid enum value' do
      expect { described_class.new(owasp_top_10: '123456') }.to raise_error(ArgumentError)
    end

    it 'accepts nil value' do
      is_expected.to allow_value(nil).for(:owasp_top_10)
    end
  end

  describe '.by_group' do
    let_it_be(:group_1) { create(:group) }
    let_it_be(:group_2) { create(:group) }
    let_it_be(:group_1_1) { create(:group, parent: group_1) }
    let_it_be(:project_1) { create(:project, group: group_1) }
    let_it_be(:project_1_1) { create(:project, group: group_1_1) }
    let_it_be(:project_2) { create(:project, group: group_2) }
    let_it_be(:vulnerability_reads_1) { create_list(:vulnerability_read, 3, project: project_1) }
    let_it_be(:vulnerability_reads_1_1) { create_list(:vulnerability_read, 3, project: project_1_1) }
    let_it_be(:vulnerability_reads_2) { create_list(:vulnerability_read, 3, project: project_2) }

    subject { described_class.by_group(group_1) }

    it 'returns all records within the group hierarchy' do
      is_expected.to match_array(vulnerability_reads_1 + vulnerability_reads_1_1)
    end
  end

  describe '.unarchived' do
    let_it_be(:active_project) { create(:project) }
    let_it_be(:archived_project) { create(:project, :archived) }
    let_it_be(:archived_vulnerability_read) { create(:vulnerability_read, project: archived_project) }
    let_it_be(:unarchived_vulnerability_read) { create(:vulnerability_read, project: active_project) }

    subject(:unarchived) { described_class.unarchived }

    it { is_expected.to contain_exactly(unarchived_vulnerability_read) }
  end

  describe '.order_traversal_ids_asc' do
    let_it_be(:group_1) { create(:group) }
    let_it_be(:group_3) { create(:group) }
    let_it_be(:group_2) { create(:group, parent: group_1) }
    let_it_be(:project_1) { create(:project, group: group_1) }
    let_it_be(:project_2) { create(:project, group: group_2) }
    let_it_be(:project_3) { create(:project, group: group_3) }
    let_it_be(:vulnerability_read_3_1) { create(:vulnerability_read, project: project_3) }
    let_it_be(:vulnerability_read_3_2) { create(:vulnerability_read, project: project_3) }
    let_it_be(:vulnerability_read_2) { create(:vulnerability_read, project: project_2) }
    let_it_be(:vulnerability_read_1) { create(:vulnerability_read, project: project_1) }

    subject(:order_traversal_ids_asc) { described_class.order_traversal_ids_asc }

    it 'returns the records ordered by traversal_id and then by vulnerability_id' do
      is_expected.to eq([
        vulnerability_read_1,
        vulnerability_read_2,
        vulnerability_read_3_1,
        vulnerability_read_3_2
      ])
    end
  end

  describe '.by_group_using_nested_loop' do
    let_it_be(:parent_group) { create(:group) }
    let_it_be(:child_group) { create(:group, parent: parent_group) }
    let_it_be(:project_on_parent) { create(:project, group: parent_group) }
    let_it_be(:project_on_child) { create(:project, group: child_group) }
    let_it_be(:vulnerability_read_on_parent) { create(:vulnerability_read, project: project_on_parent) }
    let_it_be(:vulnerability_read_on_child) { create(:vulnerability_read, project: project_on_child) }

    context 'when the parent group is given' do
      subject(:vulnerability_reads) { described_class.by_group_using_nested_loop(parent_group) }

      it 'returns all the vulnerability read records associated with the groups in hierarchy' do
        expect(vulnerability_reads).to match_array([vulnerability_read_on_parent, vulnerability_read_on_child])
      end
    end

    context 'when the child group is given' do
      subject(:vulnerability_reads) { described_class.by_group_using_nested_loop(child_group) }

      it 'returns all the vulnerability read records associated with the group' do
        expect(vulnerability_reads).to match_array([vulnerability_read_on_child])
      end
    end
  end

  describe '.all_vulnerable_traversal_ids_for' do
    let(:parent_group) { create(:group) }
    let(:child_group_1) { create(:group, parent: parent_group) }
    let(:child_group_2) { create(:group, parent: parent_group) }
    let(:project_on_parent) { create(:project, group: parent_group) }
    let(:project_on_child_1) { create(:project, group: child_group_1) }
    let(:project_on_child_2) { create(:project, :archived, group: child_group_2) }

    subject(:traversal_ids) { described_class.all_vulnerable_traversal_ids_for(parent_group).pluck(:traversal_ids) }

    before do
      create(:vulnerability_read, project: project_on_parent)
      create(:vulnerability_read, project: project_on_child_1)
      create(:vulnerability_read, project: project_on_child_1)
      create(:vulnerability_read, project: project_on_child_2)
    end

    it 'returns all the traversal IDs for non-archived records' do
      expect(traversal_ids).to match_array([parent_group.traversal_ids, child_group_1.traversal_ids])
    end
  end

  describe 'before & after in parent group scopes' do
    let_it_be(:parent_group) { create(:group) }
    let_it_be(:child_group_1) { create(:group, parent: parent_group) }
    let_it_be(:child_group_2) { create(:group, parent: parent_group) }
    let_it_be(:child_group_1_1) { create(:group, parent: child_group_1) }
    let_it_be(:project_on_parent) { create(:project, group: parent_group) }
    let_it_be(:project_on_child_1) { create(:project, group: child_group_1) }
    let_it_be(:project_on_child_2) { create(:project, :archived, group: child_group_2) }
    let_it_be(:project_on_child_1_1) { create(:project, group: child_group_1_1) }

    let_it_be(:vulnerability_on_project_on_parent) { create(:vulnerability_read, project: project_on_parent) }
    let_it_be(:vulnerability_on_project_on_child_1) { create(:vulnerability_read, project: project_on_child_1) }
    let_it_be(:another_vulnerability_on_project_on_child_1) { create(:vulnerability_read, project: project_on_child_1) }
    let_it_be(:vulnerability_on_project_on_child_2) { create(:vulnerability_read, project: project_on_child_2) }
    let_it_be(:vulnerability_on_project_on_child_1_1) { create(:vulnerability_read, project: project_on_child_1_1) }

    describe '.in_parent_group_after_and_including' do
      subject { described_class.in_parent_group_after_and_including(another_vulnerability_on_project_on_child_1) }

      it do
        is_expected.to match_array([
          another_vulnerability_on_project_on_child_1,
          vulnerability_on_project_on_child_2,
          vulnerability_on_project_on_child_1_1
        ])
      end
    end

    describe '.in_parent_group_before_and_including' do
      subject { described_class.in_parent_group_before_and_including(another_vulnerability_on_project_on_child_1) }

      it do
        is_expected.to match_array([
          vulnerability_on_project_on_parent,
          vulnerability_on_project_on_child_1,
          another_vulnerability_on_project_on_child_1
        ])
      end
    end
  end

  describe '.by_ids_desc' do
    let_it_be(:vulnerability_read) { create(:vulnerability_read, project: project) }
    let_it_be(:other_vulnerability_read) { create(:vulnerability_read, project: project) }

    it 'returns vulnerabilities for given vulnerability ids sorted by vulnerability_id' do
      results = described_class.by_ids_desc([vulnerability_read.vulnerability_id, other_vulnerability_read.vulnerability_id])

      expect(results).to match_array([vulnerability_read, other_vulnerability_read].sort_by(&:vulnerability_id).reverse)
    end
  end

  describe '.arel_grouping_by_traversal_ids_and_vulnerability_id' do
    subject { described_class.arel_grouping_by_traversal_ids_and_vulnerability_id.to_sql }

    it { is_expected.to eq('("vulnerability_reads"."traversal_ids", "vulnerability_reads"."vulnerability_id")') }
  end

  describe 'Elastic::ApplicationVersionedSearch' do
    let(:vulnerability_read) { create(:vulnerability_read, project: project) }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
      allow(Elastic::ProcessBookkeepingService).to receive(:track!)
    end

    shared_examples 'does not use elasticsearch' do
      describe '#maintaining_elasticsearch?' do
        it 'returns false' do
          expect(vulnerability_read.maintaining_elasticsearch?).to be(false)
        end
      end
    end

    shared_examples 'uses elasticsearch' do
      describe '#maintaining_elasticsearch?' do
        it 'returns true' do
          expect(vulnerability_read.maintaining_elasticsearch?).to be(true)
        end
      end

      context 'on create' do
        it 'tracks vulnerability read creation in elasticsearch' do
          expect(Elastic::ProcessBookkeepingService)
            .to have_received(:track!)
            .with(vulnerability_read)
            .once

          vulnerability_read
        end
      end

      context 'on delete' do
        it 'tracks vulnerability read deletion in elasticsearch' do
          expect(Elastic::ProcessBookkeepingService)
            .to have_received(:track!)
            .with(vulnerability_read)
            .once

          vulnerability_read.destroy!
        end
      end

      context 'on update' do
        context 'when an elastic field is updated' do
          it 'tracks vulnerability read update in elasticsearch' do
            expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(vulnerability_read).once

            vulnerability_read.update!(resolved_on_default_branch: true)
          end
        end

        context 'when a non-elastic field is updated' do
          it 'does not call track' do
            expect(Elastic::ProcessBookkeepingService).not_to receive(:track!).with(vulnerability_read)

            vulnerability_read.update!(owasp_top_10: 'A1:2021-Broken Access Control')
          end
        end
      end
    end

    it 'includes Elastic::ApplicationVersionedSearch' do
      expect(described_class).to include_module(Elastic::ApplicationVersionedSearch)
    end

    context 'when vulnerability indexing is allowed' do
      before do
        allow(::Search::Elastic::VulnerabilityIndexHelper).to receive(:indexing_allowed?).and_return(true)
      end

      it_behaves_like 'uses elasticsearch'
    end

    context 'when vulnerability indexing is disallowed' do
      before do
        allow(::Search::Elastic::VulnerabilityIndexHelper).to receive(:indexing_allowed?).and_return(false)
      end

      it_behaves_like 'does not use elasticsearch'
    end

    context 'when elasticsearch indexing is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it_behaves_like 'does not use elasticsearch'
    end
  end

  describe '#es_parent' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be(:vulnerability_read) { create(:vulnerability_read, project: project) }

    it 'returns the correct es_parent string' do
      expect(vulnerability_read.es_parent).to eq("group_#{group.id}")
    end
  end

  describe '#elastic_reference', :elastic_helpers do
    let_it_be(:vulnerability_read) { create(:vulnerability_read, project: project) }

    before do
      set_elasticsearch_migration_to(:create_vulnerability_reads_index)
    end

    it 'returns an array with both Vulnerability and Vulnerabilities::Read reference strings' do
      result = vulnerability_read.elastic_reference

      expect(result).to match_array([
        Search::Elastic::References::Vulnerability.serialize(vulnerability_read),
        Search::Elastic::References::Vulnerabilities::Read.serialize(vulnerability_read)
      ])
    end

    context 'when the create_vulnerability_reads_index migration has not finished' do
      before do
        set_elasticsearch_migration_to(:create_vulnerability_reads_index, including: false)
      end

      it 'returns only the Vulnerability reference string' do
        result = vulnerability_read.elastic_reference

        expect(result).to eq(Search::Elastic::References::Vulnerability.serialize(vulnerability_read))
      end
    end
  end

  describe '#dual_write_to_es?' do
    let_it_be(:vulnerability_read) { create(:vulnerability_read, project: project) }

    before do
      allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
        .with(:create_vulnerability_reads_index).and_return(migration_finished)
    end

    context 'when migration has finished' do
      let(:migration_finished) { true }

      it { expect(vulnerability_read.dual_write_to_es?).to be(true) }
    end

    context 'when migration has not finished' do
      let(:migration_finished) { false }

      it { expect(vulnerability_read.dual_write_to_es?).to be(false) }
    end
  end

  describe '#arel_grouping_by_traversal_ids_and_id' do
    let(:group) { build(:group, traversal_ids: [1, 2]) }
    let(:project) { build(:project, namespace: group) }
    let(:vulnerability_read) { build(:vulnerability_read, id: 1, project: project) }

    subject { vulnerability_read.arel_grouping_by_traversal_ids_and_id.to_sql }

    it { is_expected.to eq("('{1,2}', 1)") }
  end

  context 'with loose foreign key on vulnerability_reads.casted_cluster_agent_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:cluster_agent) }
      let_it_be(:model) { create(:vulnerability_read, casted_cluster_agent_id: parent.id) }
    end
  end

  context 'with loose foreign key on vulnerability_reads.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerability_read, project: parent) }
    end
  end

  describe 'skip insert_vulnerability_reads_from_vulnerability() with feature flag' do
    let(:user) { create(:user) }
    let(:identifier) { create(:vulnerabilities_identifier, project: project) }
    let(:scanner) { create(:vulnerabilities_scanner, project: project) }
    let(:vulnerability) { create(:vulnerability, project: project, present_on_default_branch: false) }
    let!(:finding) { create_finding(vulnerability: vulnerability) }

    context 'when vulnerability_management.dont_execute_db_trigger is true' do
      before do
        ::SecApplicationRecord.connection.execute(
          "SELECT set_config('vulnerability_management.dont_execute_db_trigger', 'true', true);"
        )
      end

      it 'database trigger returns NULL and does not create vulnerability_reads record' do
        expect do
          # This will hit trigger_insert_vulnerability_reads_from_vulnerability
          vulnerability.update!(present_on_default_branch: true)
        end.not_to change { Vulnerabilities::Read.count }
      end
    end

    context 'when vulnerability_management.dont_execute_db_trigger is false or unset' do
      before do
        ::SecApplicationRecord.connection.execute(
          "SELECT set_config('vulnerability_management.dont_execute_db_trigger', 'false', true);"
        )
      end

      it 'database trigger proceeds normally and creates vulnerability_reads record' do
        expect do
          vulnerability.update!(present_on_default_branch: true)
        end.to change { Vulnerabilities::Read.count }.by(1)
      end
    end
  end

  describe 'skip insert_or_update_vulnerability_reads() with feature flag' do
    let(:user) { create(:user) }
    let(:identifier) { create(:vulnerabilities_identifier, project: project) }
    let(:scanner) { create(:vulnerabilities_scanner, project: project) }
    let(:vulnerability) { create(:vulnerability, project: project, present_on_default_branch: true) }

    context 'when vulnerability_management.dont_execute_db_trigger is true' do
      before do
        ::SecApplicationRecord.connection.execute(
          "SELECT set_config('vulnerability_management.dont_execute_db_trigger', 'true', true);"
        )
      end

      it 'database trigger returns NULL and does not create vulnerability_reads record' do
        expect do
          # This will hit trigger_insert_or_update_vulnerability_reads_from_occurrences
          create_finding(vulnerability: vulnerability)
        end.not_to change { Vulnerabilities::Read.count }
      end
    end

    context 'when vulnerability_management.dont_execute_db_trigger is false or unset' do
      before do
        ::SecApplicationRecord.connection.execute(
          "SELECT set_config('vulnerability_management.dont_execute_db_trigger', 'false', true);"
        )
      end

      it 'database trigger proceeds normally and creates vulnerability_reads record' do
        expect do
          create_finding(vulnerability: vulnerability)
        end.to change { Vulnerabilities::Read.count }.by(1)
      end
    end
  end

  private

  def create_vulnerability(severity: 7, report_type: 0)
    create(:vulnerability,
      project: project,
      author: user,
      severity: severity,
      report_type: report_type
    )
  end

  # rubocop:disable Metrics/ParameterLists
  def create_finding(
    vulnerability: nil, primary_identifier: identifier, severity: 7, report_type: 0,
    location: { "image" => "alpine:3.4" }, location_fingerprint: 'test',
    metadata_version: 'test', raw_metadata: 'test', uuid: SecureRandom.uuid)
    create(:vulnerabilities_finding,
      vulnerability: vulnerability,
      project: project,
      severity: severity,
      report_type: report_type,
      scanner: scanner,
      primary_identifier: primary_identifier,
      location: location,
      location_fingerprint: location_fingerprint,
      metadata_version: metadata_version,
      raw_metadata: raw_metadata,
      uuid: uuid
    )
  end
  # rubocop:enable Metrics/ParameterLists
end
