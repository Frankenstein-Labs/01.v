# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicyViolation, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:scan_result_policy_read) }
    it { is_expected.to belong_to(:approval_policy_rule) }
    it { is_expected.to belong_to(:merge_request) }
    it { is_expected.to have_one(:security_policy).through(:approval_policy_rule) }
    it { is_expected.to have_many(:violation_details).class_name('Security::ScanResultPolicyViolationDetail').inverse_of(:violation) }
  end

  describe 'validations' do
    let_it_be_with_reload(:violation) { create(:scan_result_policy_violation) }

    subject { violation }

    it { is_expected.to(validate_uniqueness_of(:scan_result_policy_id).scoped_to(%i[merge_request_id])) }

    describe 'violation_data' do
      it { is_expected.not_to allow_value('string').for(:violation_data) }
      it { is_expected.to allow_value({}).for(:violation_data) }

      it 'allows combination of all possible values' do
        is_expected.to allow_value(
          {
            violations: {
              scan_finding: { uuids: { newly_detected: ['123'], previously_existing: ['456'] } },
              license_scanning: { 'MIT' => ['A'] },
              any_merge_request: { commits: ['abcd1234'] }
            },
            context: { pipeline_ids: [123], target_pipeline_ids: [456] },
            errors: [{ error: 'SCAN_REMOVED', missing_scans: ['sast'] }]
          }
        ).for(:violation_data)
      end

      describe 'errors' do
        it do
          is_expected.to allow_value(
            { errors: [{ error: 'SCAN_REMOVED', missing_scans: ['sast'] }] }
          ).for(:violation_data)
        end
      end

      it { is_expected.not_to allow_value({ errors: [{}] }).for(:violation_data) }

      describe 'violations' do
        using RSpec::Parameterized::TableSyntax

        describe 'commits' do
          where(:report_type, :data, :valid) do
            :any_merge_request | { commits: ['abcd1234'] } | true
            :any_merge_request | { commits: true }         | true
            :any_merge_request | { commits: 'abcd1234' }   | false
            :any_merge_request | { commits: [] }           | false
          end

          with_them do
            it do
              if valid
                expect(violation).to allow_value(violations: { report_type => data }).for(:violation_data)
              else
                expect(violation).not_to allow_value(violations: { report_type => data }).for(:violation_data)
              end
            end
          end
        end

        describe 'scan_finding' do
          where(:data, :valid) do
            { uuids: { newly_detected: ['uuid-1'] } } | true
            { uuids: { previously_existing: ['uuid-1'] } } | true
            { uuids: { newly_detected: ['uuid-1'], previously_existing: ['uuid-2'] } } | true
            { uuids: { previously_existing: ['uuid-1'], newly_detected: ['uuid-2'] } } | true
            { uuids: { newly_detected: %w[uuid-1 uuid-2 uuid-3] } } | true
            { uuids: { previously_existing: %w[uuid-1 uuid-2 uuid-3] } } | true
            { uuids: { newly_detected: ['a' * 50] } } | true
            { uuids: { previously_existing: ['a' * 50] } } | true
            { uuids: { newly_detected: [] } } | false
            { uuids: { previously_existing: [] } } | false
            { uuids: { newly_detected: ['a' * 51] } } | false
            { uuids: { previously_existing: ['a' * 51] } } | false
            { uuids: { newly_detected: 'uuid-1' } } | false
            { uuids: { previously_existing: 'uuid-1' } } | false
            { uuids: { newly_detected: [123] } } | false
            { uuids: { previously_existing: [123] } } | false
            { uuids: { invalid_state: ['uuid-1'] } } | false
            { uuids: {} } | false
            {} | false
          end

          with_them do
            it do
              if valid
                expect(violation).to allow_value(violations: { scan_finding: data }).for(:violation_data)
              else
                expect(violation).not_to allow_value(violations: { scan_finding: data }).for(:violation_data)
              end
            end
          end
        end
      end
    end
  end

  describe '.for_approval_rules' do
    let_it_be_with_reload(:violation) { create(:scan_result_policy_violation) }

    subject { described_class.for_approval_rules(approval_rules) }

    context 'when approval rules are empty' do
      let(:approval_rules) { [] }

      it { is_expected.to be_empty }
    end

    context 'when approval rules are present' do
      let_it_be(:project) { create(:project) }
      let_it_be(:scan_result_policy_read_1) { create(:scan_result_policy_read, project: project) }
      let_it_be(:scan_result_policy_read_2) { create(:scan_result_policy_read, project: project) }
      let_it_be(:scan_result_policy_read_3) { create(:scan_result_policy_read, project: project) }
      let_it_be(:other_violations) do
        [
          create(:scan_result_policy_violation, project: project, scan_result_policy_read: scan_result_policy_read_2),
          create(:scan_result_policy_violation, project: project, scan_result_policy_read: scan_result_policy_read_3)
        ]
      end

      let(:approval_rules) do
        create_list(:report_approver_rule, 1, :scan_finding, scan_result_policy_read: scan_result_policy_read_1)
      end

      let_it_be(:scan_finding_violation) do
        create(:scan_result_policy_violation, project: project, scan_result_policy_read: scan_result_policy_read_1)
      end

      it { is_expected.to contain_exactly scan_finding_violation }
    end
  end

  describe '.including_approval_policy_rules_with_policies' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:security_policy) { create(:security_policy) }
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }
    let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }
    let_it_be(:violation) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: scan_result_policy_read, approval_policy_rule: approval_policy_rule)
    end

    subject(:scoped) { described_class.including_approval_policy_rules_with_policies }

    it 'eager-loads approval_policy_rule and its security_policy' do
      result = scoped.to_a

      expect(result).to include(violation)
      expect(result.first.association(:approval_policy_rule)).to be_loaded
      expect(result.first.approval_policy_rule.association(:security_policy)).to be_loaded
    end

    it 'does not generate N+1 queries when accessing approval_policy_rule and security_policy', :use_sql_query_cache do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: create(:scan_result_policy_read, project: project),
        approval_policy_rule: create(:approval_policy_rule, security_policy: create(:security_policy)))

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        described_class.including_approval_policy_rules_with_policies.each do |v|
          v.approval_policy_rule&.security_policy
        end
      end

      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: create(:scan_result_policy_read, project: project),
        approval_policy_rule: create(:approval_policy_rule, security_policy: create(:security_policy)))

      expect do
        described_class.including_approval_policy_rules_with_policies.each do |v|
          v.approval_policy_rule&.security_policy
        end
      end.not_to exceed_all_query_limit(control)
    end
  end

  describe '.for_merge_request_and_approval_policy_rules' do
    let_it_be(:merge_request) { create(:merge_request) }
    let_it_be(:approval_policy_rule) { create(:approval_policy_rule) }
    let_it_be(:other_approval_policy_rule) { create(:approval_policy_rule) }
    let_it_be(:violation) do
      create(:scan_result_policy_violation, merge_request: merge_request, approval_policy_rule: approval_policy_rule)
    end

    let_it_be(:violation_for_other_approval_policy_rule) do
      create(:scan_result_policy_violation, merge_request: merge_request,
        approval_policy_rule: other_approval_policy_rule)
    end

    let_it_be(:violation_for_other_merge_request) do
      create(:scan_result_policy_violation, approval_policy_rule: approval_policy_rule)
    end

    subject do
      described_class.for_merge_request_and_approval_policy_rules(merge_request, [approval_policy_rule.id])
    end

    it { is_expected.to contain_exactly(violation) }

    context 'when no approval policy rule ids are given' do
      subject { described_class.for_merge_request_and_approval_policy_rules(merge_request, []) }

      it { is_expected.to be_empty }
    end
  end

  describe '.with_violation_data' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }
    let_it_be(:scan_result_policy_read_2) { create(:scan_result_policy_read, project: project) }
    let_it_be(:violation_with_data) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: scan_result_policy_read)
    end

    let_it_be(:violation_without_data) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: scan_result_policy_read_2, violation_data: nil)
    end

    subject { described_class.with_violation_data }

    it { is_expected.to contain_exactly violation_with_data }
  end

  describe '.with_security_policy_dismissal' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:other_merge_request) { create(:merge_request, :unique_branches, source_project: project) }
    let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }
    let_it_be(:security_policy_1) { create(:security_policy) }
    let_it_be(:security_policy_2) { create(:security_policy) }
    let_it_be(:approval_policy_rule_1) do
      create(:approval_policy_rule, security_policy: security_policy_1)
    end

    let_it_be(:approval_policy_rule_2) do
      create(:approval_policy_rule, security_policy: security_policy_2)
    end

    let_it_be(:violation_with_dismissal) do
      create(:scan_result_policy_violation,
        project: project,
        merge_request: merge_request,
        scan_result_policy_read: scan_result_policy_read,
        approval_policy_rule: approval_policy_rule_1
      )
    end

    let_it_be(:violation_without_dismissal) do
      create(:scan_result_policy_violation,
        project: project,
        merge_request: other_merge_request,
        scan_result_policy_read: scan_result_policy_read,
        approval_policy_rule: approval_policy_rule_2
      )
    end

    let_it_be(:policy_dismissal) do
      create(:policy_dismissal,
        project: project,
        merge_request: merge_request,
        security_policy: security_policy_1
      )
    end

    subject(:with_security_policy_dismissal) do
      described_class.with_security_policy_dismissal
    end

    it 'returns only violations that have dismissals for the given merge request' do
      expect(with_security_policy_dismissal).to contain_exactly(violation_with_dismissal)
    end
  end

  describe '.without_violation_data' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }
    let_it_be(:scan_result_policy_read_2) { create(:scan_result_policy_read, project: project) }
    let_it_be(:violation_with_data) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: scan_result_policy_read)
    end

    let_it_be(:violation_without_data) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request,
        scan_result_policy_read: scan_result_policy_read_2, violation_data: nil)
    end

    subject { described_class.without_violation_data }

    it { is_expected.to contain_exactly violation_without_data }
  end

  describe '.trim_violations' do
    subject(:trimmed_violations) { described_class.trim_violations(violations) }

    let(:violations) { ['uuid'] * (Security::ScanResultPolicyViolation::MAX_VIOLATIONS + 2) }

    it 'returns MAX_VIOLATIONS+1 number of violations' do
      expect(trimmed_violations.size).to eq Security::ScanResultPolicyViolation::MAX_VIOLATIONS + 1
      expect(trimmed_violations).to eq(violations[..Security::ScanResultPolicyViolation::MAX_VIOLATIONS])
    end

    context 'when violations are nil' do
      let(:violations) { nil }

      it { is_expected.to be_empty }
    end
  end

  describe '.running' do
    let_it_be(:running_violation) { create(:scan_result_policy_violation, :running) }
    let_it_be(:failed_violation) { create(:scan_result_policy_violation, :failed) }

    it 'returns only running violations' do
      expect(described_class.running).to contain_exactly(running_violation)
    end
  end

  describe '.for_security_policies' do
    let_it_be(:policy_1) { create(:security_policy) }
    let_it_be(:policy_2) { create(:security_policy) }
    let_it_be(:rule_1) { create(:approval_policy_rule, security_policy: policy_1) }
    let_it_be(:rule_2) { create(:approval_policy_rule, security_policy: policy_2) }
    let_it_be(:violation_1) { create(:scan_result_policy_violation, approval_policy_rule: rule_1) }
    let_it_be(:violation_2) { create(:scan_result_policy_violation, approval_policy_rule: rule_2) }
    let_it_be(:violation_without_rule) { create(:scan_result_policy_violation, approval_policy_rule: nil) }

    subject(:violations) { described_class.for_security_policies(policies) }

    context 'when filtering by a single policy' do
      let(:policies) { policy_1 }

      it { is_expected.to contain_exactly(violation_1) }
    end

    context 'when filtering by multiple policies' do
      let(:policies) { [policy_1, policy_2] }

      it { is_expected.to contain_exactly(violation_1, violation_2) }
    end

    context 'when filtering by a policy with no violations' do
      let(:policies) { create(:security_policy) }

      it { is_expected.to be_empty }
    end
  end

  describe '.group_by_security_policy_id' do
    let_it_be(:policy_1) { create(:security_policy) }
    let_it_be(:policy_2) { create(:security_policy) }

    let_it_be(:rule_for_policy_1) { create(:approval_policy_rule, security_policy: policy_1) }
    let_it_be(:rule_for_policy_2) { create(:approval_policy_rule, security_policy: policy_2) }

    let_it_be(:violation_for_policy_1_a) do
      create(:scan_result_policy_violation, approval_policy_rule: rule_for_policy_1)
    end

    let_it_be(:violation_for_policy_1_b) do
      create(:scan_result_policy_violation, approval_policy_rule: rule_for_policy_1)
    end

    let_it_be(:violation_for_policy_2) do
      create(:scan_result_policy_violation, approval_policy_rule: rule_for_policy_2)
    end

    let_it_be(:violation_without_rule) { create(:scan_result_policy_violation, approval_policy_rule: nil) }

    subject(:grouped_violations) { described_class.where(id: violations).group_by_security_policy_id }

    context 'when grouping violations with and without rules' do
      let(:violations) do
        [violation_for_policy_1_a, violation_for_policy_1_b, violation_for_policy_2, violation_without_rule]
      end

      it 'groups violations by security_policy_id and handles nil rules' do
        expect(grouped_violations.keys).to contain_exactly(policy_1.id, policy_2.id, nil)
        expect(grouped_violations[policy_1.id].pluck(:id)).to contain_exactly(violation_for_policy_1_a.id,
          violation_for_policy_1_b.id)
        expect(grouped_violations[policy_2.id].pluck(:id)).to contain_exactly(violation_for_policy_2.id)
        expect(grouped_violations[nil].pluck(:id)).to contain_exactly(violation_without_rule.id)
      end
    end
  end

  describe '.for_scan_result_policy_read' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }

    before_all do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request)
    end

    subject(:result) { described_class.for_scan_result_policy_read(scan_result_policy_read) }

    context 'when scan_result_policy_read has violations' do
      let_it_be(:violation_for_policy) do
        create(:scan_result_policy_violation, project: project, merge_request: merge_request,
          scan_result_policy_read: scan_result_policy_read)
      end

      it 'returns only violations for that policy read' do
        expect(result).to contain_exactly(violation_for_policy)
      end
    end

    context 'when scan_result_policy_read has no violations' do
      it 'returns empty result' do
        expect(result).to be_empty
      end
    end
  end

  describe '.for_merge_request' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request_1) { create(:merge_request, :unique_branches, source_project: project) }
    let_it_be(:merge_request_2) { create(:merge_request, :unique_branches, source_project: project) }
    let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }

    let_it_be(:violation_for_mr1) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request_1,
        scan_result_policy_read: scan_result_policy_read)
    end

    let_it_be(:violation_for_mr2) do
      create(:scan_result_policy_violation, project: project, merge_request: merge_request_2,
        scan_result_policy_read: scan_result_policy_read)
    end

    subject(:for_merge_request) { described_class.for_merge_request(merge_request) }

    context 'when filtering by a specific merge request' do
      let(:merge_request) { merge_request_1 }

      it 'returns only violations for that merge request' do
        expect(for_merge_request).to contain_exactly(violation_for_mr1)
      end
    end

    context 'when filtering by a different merge request' do
      let(:merge_request) { merge_request_2 }

      it 'returns only violations for that merge request' do
        expect(for_merge_request).to contain_exactly(violation_for_mr2)
      end
    end

    context 'when filtering by a merge request with no violations' do
      let(:merge_request) { create(:merge_request, :unique_branches, source_project: project) }

      it 'returns empty result' do
        expect(for_merge_request).to be_empty
      end
    end

    context 'when there are multiple violations for the same merge request' do
      let(:merge_request) { merge_request_1 }
      let_it_be(:scan_result_policy_read_2) { create(:scan_result_policy_read, project: project) }
      let_it_be(:additional_violation_for_mr1) do
        create(:scan_result_policy_violation, project: project, merge_request: merge_request_1,
          scan_result_policy_read: scan_result_policy_read_2)
      end

      it 'returns all violations for that merge request' do
        expect(for_merge_request).to contain_exactly(violation_for_mr1, additional_violation_for_mr1)
      end
    end
  end

  describe '#finding_uuids' do
    let(:violation) { build(:scan_result_policy_violation, violation_data: violation_data) }

    subject(:uuids) { violation.finding_uuids }

    def build_violation_data(previously_existing: [], newly_detected: [])
      {
        violations: {
          scan_finding: {
            uuids: {
              previously_existing: previously_existing,
              newly_detected: newly_detected
            }
          }
        }
      }
    end

    context 'when violation_data is nil' do
      let(:violation_data) { nil }

      it { is_expected.to be_empty }
    end

    context 'when violation_data is an empty hash' do
      let(:violation_data) { {} }

      it { is_expected.to be_empty }
    end

    context 'when violation_data does not contain scan_finding uuids' do
      let(:violation_data) { { violations: { license_scanning: { 'MIT' => ['A'] } } } }

      it { is_expected.to be_empty }
    end

    context 'when violation_data contains uuids' do
      where(:previously_existing, :newly_detected, :expected_uuids) do
        %w[uuid-1 uuid-2] | []                  | %w[uuid-1 uuid-2]
        []                | %w[uuid-3 uuid-4]   | %w[uuid-3 uuid-4]
        %w[uuid-1 uuid-2] | %w[uuid-3 uuid-4]   | %w[uuid-1 uuid-2 uuid-3 uuid-4]
        []                | []                  | nil
      end

      with_them do
        let(:violation_data) do
          build_violation_data(previously_existing: previously_existing, newly_detected: newly_detected)
        end

        it { is_expected.to match_array(expected_uuids) }
      end
    end
  end

  describe '#licenses' do
    let(:violation) { build(:scan_result_policy_violation, violation_data: violation_data) }

    subject(:licenses) { violation.licenses }

    context 'when violation_data is nil' do
      let(:violation_data) { nil }

      it { is_expected.to be_empty }
    end

    context 'when violation_data is empty' do
      let(:violation_data) { {} }

      it { is_expected.to be_empty }
    end

    context 'when violation_data does not contain license_scanning information' do
      let(:violation_data) do
        { violations: { scan_finding: { uuids: { previously_existing: %w[uuid-1 uuid-2], newly_detected: [] } } } }
      end

      it { is_expected.to be_empty }
    end

    context 'when violation_data contains license_scanning information' do
      let(:violation_data) do
        { violations: { license_scanning: { 'MIT License' => ['rack'], 'Ruby License' => ['json'] } } }
      end

      it { is_expected.to match({ 'MIT License' => ['rack'], 'Ruby License' => ['json'] }) }
    end
  end

  describe '#dismissed?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }
    let_it_be(:security_policy) { create(:security_policy) }
    let_it_be(:approval_policy_rule) do
      create(:approval_policy_rule, :scan_finding, security_policy: security_policy)
    end

    subject { violation.dismissed? }

    context 'when security_policy is nil' do
      let(:violation) do
        create(:scan_result_policy_violation,
          project: project,
          merge_request: merge_request,
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: nil
        )
      end

      it { is_expected.to be(false) }
    end

    context 'when no dismissal exists' do
      let(:violation) do
        create(:scan_result_policy_violation, :new_scan_finding,
          project: project,
          merge_request: merge_request,
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: approval_policy_rule,
          uuids: %w[uuid-1 uuid-2]
        )
      end

      it { is_expected.to be(false) }
    end

    context 'when dismissal exists' do
      context 'for security findings' do
        let_it_be(:policy_dismissal) do
          create(:policy_dismissal,
            project: project,
            merge_request: merge_request,
            security_policy: security_policy,
            security_findings_uuids: %w[uuid-1 uuid-2 uuid-3],
            licenses: { "MIT License": ["rack"] }
          )
        end

        context 'when violation has no finding UUIDs' do
          let(:violation) do
            create(:scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: approval_policy_rule,
              violation_data: { 'violations' => { 'any_merge_request' => { 'commits' => ['abc123'] } } }
            )
          end

          it { is_expected.to be(true) }
        end

        context 'when all finding UUIDs are dismissed' do
          let(:violation) do
            create(:scan_result_policy_violation, :new_scan_finding,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: approval_policy_rule,
              uuids: %w[uuid-1 uuid-2]
            )
          end

          it { is_expected.to be(true) }

          it 'does not execute additional queries when associations are preloaded' do
            queries_without_preload = ActiveRecord::QueryRecorder.new do
              violation.dismissed?
            end

            with_loaded_associations = described_class.with_security_policy_dismissal.find(violation.id)

            queries_with_preload = ActiveRecord::QueryRecorder.new do
              with_loaded_associations.dismissed?
            end

            expect(queries_with_preload.count).to be < queries_without_preload.count
          end
        end

        context 'when some finding UUIDs are missing from dismissal' do
          let(:violation) do
            create(:scan_result_policy_violation, :new_scan_finding,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: approval_policy_rule,
              uuids: %w[uuid-1 uuid-4]
            )
          end

          it { is_expected.to be(false) }
        end

        context 'when dismissal contains extra UUIDs beyond violation UUIDs' do
          let(:violation) do
            create(:scan_result_policy_violation, :new_scan_finding,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: approval_policy_rule,
              uuids: ['uuid-1']
            )
          end

          it { is_expected.to be(true) }
        end

        context 'when violation has both newly detected and previously existing UUIDs' do
          let(:violation) do
            create(:scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: approval_policy_rule,
              violation_data: {
                'violations' => {
                  'scan_finding' => {
                    'uuids' => {
                      'newly_detected' => ['uuid-1'],
                      'previously_existing' => ['uuid-2']
                    }
                  }
                }
              }
            )
          end

          it { is_expected.to be(true) }
        end

        context 'when violation has mixed UUIDs with some not dismissed' do
          let(:violation) do
            create(:scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: approval_policy_rule,
              violation_data: {
                'violations' => {
                  'scan_finding' => {
                    'uuids' => {
                      'newly_detected' => %w[uuid-1 uuid-missing],
                      'previously_existing' => ['uuid-2']
                    }
                  }
                }
              }
            )
          end

          it { is_expected.to be(false) }
        end
      end

      context 'with license scanning violations' do
        let_it_be(:policy_dismissal) do
          create(:policy_dismissal,
            project: project,
            merge_request: merge_request,
            security_policy: security_policy,
            licenses: { "MIT License": ["rack"], "Other License": ["dependency"] }
          )
        end

        context 'when violation has no licenses' do
          let(:violation) do
            create(:scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: approval_policy_rule
            )
          end

          it { is_expected.to be(true) }
        end

        context 'when all licenses are dismissed' do
          let(:violation) do
            create(:scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: approval_policy_rule,
              violation_data: {
                'violations' => {
                  'license_scanning' => {
                    "MIT License": ["rack"],
                    "Other License": ["dependency"]
                  }
                }
              }
            )
          end

          it { is_expected.to be(true) }

          it 'does not execute additional queries when associations are preloaded' do
            queries_without_preload = ActiveRecord::QueryRecorder.new do
              violation.dismissed?
            end

            with_loaded_associations = described_class.with_security_policy_dismissal.find(violation.id)

            queries_with_preload = ActiveRecord::QueryRecorder.new do
              with_loaded_associations.dismissed?
            end

            expect(queries_with_preload.count).to be < queries_without_preload.count
          end
        end

        context 'when some licenses are missing from dismissal' do
          let(:violation) do
            create(:scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: approval_policy_rule,
              violation_data: {
                'violations' => {
                  'license_scanning' => {
                    "MIT License": ['rack'],
                    'Ruby License': ['json']
                  }
                }
              }
            )
          end

          it { is_expected.to be(false) }
        end

        context 'when dismissal contains extra licenses' do
          let(:violation) do
            create(:scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: scan_result_policy_read,
              approval_policy_rule: approval_policy_rule,
              violation_data: { 'violations' => { 'license_scanning' => { "MIT License": ["rack"] } } }
            )
          end

          it { is_expected.to be(true) }
        end
      end
    end
  end

  describe '#bot_message_disabled?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:security_policy_with_disabled_bot_message) do
      create(:security_policy, :with_disabled_bot_message)
    end

    let_it_be(:approval_policy_rule) do
      create(:approval_policy_rule, :scan_finding, security_policy: security_policy_with_disabled_bot_message)
    end

    let(:violation) do
      build(:scan_result_policy_violation,
        project: project,
        approval_policy_rule: approval_policy_rule
      )
    end

    subject { violation.bot_message_disabled? }

    it 'delegates to the approval policy rule' do
      is_expected.to be(true)
    end

    context 'when there is no approval policy rule' do
      let(:violation) do
        build(:scan_result_policy_violation, project: project, approval_policy_rule: nil)
      end

      it { is_expected.to be_nil }
    end

    context 'when the deprecate_scan_result_policies feature flag is disabled' do
      let_it_be(:scan_result_policy_read_with_enabled_bot_message) do
        create(:scan_result_policy_read, :with_send_bot_message, project: project, bot_message_enabled: true)
      end

      let(:violation) do
        build(:scan_result_policy_violation,
          project: project,
          scan_result_policy_read: scan_result_policy_read_with_enabled_bot_message,
          approval_policy_rule: approval_policy_rule
        )
      end

      before do
        stub_feature_flags(deprecate_scan_result_policies: false)
      end

      it 'delegates to the scan result policy read' do
        is_expected.to be(false)
      end

      context 'when there is no scan result policy read' do
        let(:violation) do
          build(:scan_result_policy_violation, project: project, scan_result_policy_read: nil)
        end

        it { is_expected.to be_nil }
      end
    end
  end
end
