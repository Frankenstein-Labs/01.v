# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::CreateViolationDetailsService,
  feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:policy_rule) { create(:approval_policy_rule) }
  let_it_be(:violation) do
    create(:scan_result_policy_violation,
      merge_request: merge_request,
      project: project,
      approval_policy_rule: policy_rule)
  end

  let(:detail) { Security::ScanResultPolicyViolationDetail }

  subject(:service) do
    described_class.new(
      merge_request: merge_request,
      violation_detail_data: violation_detail_data
    )
  end

  describe '#execute' do
    let(:attrs) { [{ approval_policy_rule_id: policy_rule.id }] }

    context 'with scan_finding violations' do
      let(:uuid1) { SecureRandom.uuid }
      let(:uuid2) { SecureRandom.uuid }

      let(:violation_detail_data) do
        {
          policy_rule.id => {
            'full_newly_detected_uuids' => [uuid1],
            'full_previously_existing_uuids' => [uuid2]
          }
        }
      end

      it 'creates one detail row per UUID with correct finding_state', :aggregate_failures do
        expect { service.execute(attrs) }.to change { detail.count }.by(2)

        rows = detail.where(scan_result_policy_violation_id: violation.id).order(:finding_uuid)
        expect(rows).to contain_exactly(
          have_attributes(finding_uuid: uuid1, finding_state: 'newly_detected',
            policy_rule_type: 'scan_finding', project_id: project.id),
          have_attributes(finding_uuid: uuid2, finding_state: 'previously_existing',
            policy_rule_type: 'scan_finding', project_id: project.id)
        )
      end

      it 'replaces existing detail rows on re-execution (idempotent)' do
        service.execute(attrs)

        expect { service.execute(attrs) }.not_to change { detail.count }
      end

      context 'when only newly_detected UUIDs are present' do
        let(:violation_detail_data) do
          { policy_rule.id => { 'full_newly_detected_uuids' => [uuid1, uuid2] } }
        end

        it 'creates rows with newly_detected state' do
          expect { service.execute(attrs) }.to change { detail.count }.by(2)
          rows = detail.where(scan_result_policy_violation_id: violation.id).order(:finding_uuid)
          expect(rows).to contain_exactly(
            have_attributes(finding_uuid: uuid1, finding_state: 'newly_detected',
              policy_rule_type: 'scan_finding', project_id: project.id),
            have_attributes(finding_uuid: uuid2, finding_state: 'newly_detected',
              policy_rule_type: 'scan_finding', project_id: project.id)
          )
        end
      end

      context 'when only previously_existing UUIDs are present' do
        let(:violation_detail_data) do
          { policy_rule.id => { 'full_previously_existing_uuids' => [uuid2] } }
        end

        it 'creates one row with previously_existing state' do
          expect { service.execute(attrs) }.to change { detail.count }.by(1)

          rows = detail.where(scan_result_policy_violation_id: violation.id).order(:finding_uuid)
          expect(rows).to contain_exactly(
            have_attributes(finding_uuid: uuid2, finding_state: 'previously_existing',
              policy_rule_type: 'scan_finding', project_id: project.id)
          )
        end
      end

      context 'when violation_detail_data is absent' do
        let(:violation_detail_data) { {} }

        it 'creates no detail rows' do
          expect { service.execute(attrs) }.not_to change { detail.count }
        end
      end
    end

    context 'with license_scanning violations' do
      let(:violation_detail_data) do
        {
          policy_rule.id => {
            'full_dependencies_by_license' => { 'MIT License' => %w[dep1 dep2] }
          }
        }
      end

      it 'derives total from the dependencies array size' do
        service.execute(attrs)

        row = detail.license_scanning.find_by(license_name: 'MIT License')
        expect(row.total_dependencies_count).to eq(2)
      end

      it 'stores the dependencies array' do
        service.execute(attrs)

        row = detail.license_scanning.find_by(license_name: 'MIT License')
        expect(row.dependencies).to eq(%w[dep1 dep2])
      end

      context 'when violation_detail_data is absent' do
        let(:violation_detail_data) { {} }

        it 'creates no detail rows' do
          expect { service.execute(attrs) }.not_to change { detail.count }
        end
      end

      context 'when there are multiple licenses' do
        let(:violation_detail_data) do
          {
            policy_rule.id => {
              'full_dependencies_by_license' => {
                'MIT License' => %w[dep1 dep2],
                'Apache-2.0' => %w[dep3]
              }
            }
          }
        end

        it 'creates one row per license' do
          expect { service.execute(attrs) }.to change { detail.count }.by(2)

          license_names = detail.license_scanning.pluck(:license_name)
          expect(license_names).to contain_exactly('MIT License', 'Apache-2.0')
        end
      end

      context 'when dependencies exceed MAX_ARRAY_LIMIT' do
        let(:many_deps) { (1..15).map { |i| "dep#{i}" } }
        let(:violation_detail_data) do
          {
            policy_rule.id => {
              'full_dependencies_by_license' => { 'MIT License' => many_deps }
            }
          }
        end

        it 'truncates dependencies to MAX_ARRAY_LIMIT' do
          service.execute(attrs)

          row = detail.license_scanning.find_by(license_name: 'MIT License')
          expect(row.dependencies.size).to eq(Security::ScanResultPolicyViolationDetail::MAX_ARRAY_LIMIT)
          expect(row.dependencies).to eq(many_deps.first(Security::ScanResultPolicyViolationDetail::MAX_ARRAY_LIMIT))
        end

        it 'stores the full count derived from the array size' do
          service.execute(attrs)

          row = detail.license_scanning.find_by(license_name: 'MIT License')
          expect(row.total_dependencies_count).to eq(many_deps.size)
        end
      end
    end

    context 'with any_merge_request violations' do
      let(:full_shas) { %w[abc123 def456] }
      let(:violation_detail_data) do
        {
          policy_rule.id => {
            'full_commit_shas' => full_shas
          }
        }
      end

      it 'derives total from the commit shas array size' do
        service.execute(attrs)

        row = detail.any_merge_request.order(:id).first
        expect(row.total_commit_shas_count).to eq(full_shas.size)
      end

      it 'stores the commit_shas array' do
        service.execute(attrs)

        row = detail.any_merge_request.order(:id).first
        expect(row.commit_shas).to eq(full_shas)
      end

      context 'when violation_detail_data is absent' do
        let(:violation_detail_data) { {} }

        it 'creates no detail rows' do
          expect { service.execute(attrs) }.not_to change { detail.count }
        end
      end

      context 'when full_commit_shas exceeds MAX_ARRAY_LIMIT' do
        let(:many_commits) { (1..15).map { |i| "sha#{i}" } }
        let(:violation_detail_data) do
          {
            policy_rule.id => {
              'full_commit_shas' => many_commits
            }
          }
        end

        it 'truncates commit_shas to MAX_ARRAY_LIMIT' do
          service.execute(attrs)

          row = detail.any_merge_request.order(:id).first
          expect(row.commit_shas.size).to eq(Security::ScanResultPolicyViolationDetail::MAX_ARRAY_LIMIT)
          expect(row.commit_shas).to eq(many_commits.first(Security::ScanResultPolicyViolationDetail::MAX_ARRAY_LIMIT))
        end

        it 'stores the full count derived from the array size' do
          service.execute(attrs)

          row = detail.any_merge_request.order(:id).first
          expect(row.total_commit_shas_count).to eq(many_commits.size)
        end
      end

      context 'when full_commit_shas is not an array' do
        let(:violation_detail_data) do
          { policy_rule.id => { 'full_commit_shas' => true } }
        end

        it 'creates no detail rows' do
          expect { service.execute(attrs) }.not_to change { detail.count }
        end
      end
    end

    context 'when violation_detail_data is empty' do
      let(:violation_detail_data) { {} }

      it 'creates no detail rows' do
        expect { service.execute(attrs) }.not_to change { detail.count }
      end
    end

    context 'when violation has all three rule types' do
      let(:uuid) { SecureRandom.uuid }
      let(:violation_detail_data) do
        {
          policy_rule.id => {
            'full_newly_detected_uuids' => [uuid],
            'full_dependencies_by_license' => { 'MIT License' => %w[dep1] },
            'full_commit_shas' => %w[sha1]
          }
        }
      end

      it 'creates rows for all three types' do
        expect { service.execute(attrs) }.to change { detail.count }.by(3)

        expect(detail.scan_finding.count).to eq(1)
        expect(detail.license_scanning.count).to eq(1)
        expect(detail.any_merge_request.count).to eq(1)
      end
    end

    context 'when there are multiple violations for different policy rules' do
      let_it_be(:policy_rule_b) { create(:approval_policy_rule) }
      let_it_be(:violation_b) do
        create(:scan_result_policy_violation,
          merge_request: merge_request,
          project: project,
          approval_policy_rule: policy_rule_b)
      end

      let(:uuid_a) { SecureRandom.uuid }
      let(:uuid_b) { SecureRandom.uuid }
      let(:violation_detail_data) do
        {
          policy_rule.id => { 'full_newly_detected_uuids' => [uuid_a] },
          policy_rule_b.id => { 'full_newly_detected_uuids' => [uuid_b] }
        }
      end

      let(:attrs) do
        [
          { approval_policy_rule_id: policy_rule.id },
          { approval_policy_rule_id: policy_rule_b.id }
        ]
      end

      it 'creates rows for each violation', :aggregate_failures do
        expect { service.execute(attrs) }.to change { detail.count }.by(2)

        expect(detail.find_by(scan_result_policy_violation_id: violation.id)).to have_attributes(
          finding_uuid: uuid_a, finding_state: 'newly_detected',
          policy_rule_type: 'scan_finding', project_id: project.id)
        expect(detail.find_by(scan_result_policy_violation_id: violation_b.id)).to have_attributes(
          finding_uuid: uuid_b, finding_state: 'newly_detected',
          policy_rule_type: 'scan_finding', project_id: project.id)
      end
    end

    context 'when deprecate_scan_result_policies feature flag is disabled' do
      let_it_be(:scan_result_policy_read) do
        create(:scan_result_policy_read, project: project, approval_policy_rule: policy_rule)
      end

      let_it_be(:legacy_violation) do
        create(:scan_result_policy_violation,
          merge_request: merge_request,
          project: project,
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: policy_rule)
      end

      let(:uuid) { SecureRandom.uuid }
      let(:violation_detail_data) { {} }

      before do
        stub_feature_flags(deprecate_scan_result_policies: false)
      end

      it 'creates no rows when violation_detail_data keys do not match scan_result_policy_id' do
        legacy_attrs = [{ scan_result_policy_id: scan_result_policy_read.id }]

        expect { service.execute(legacy_attrs) }.not_to change { detail.count }
      end

      it 'creates rows when violation_detail_data is keyed by scan_result_policy_id' do
        legacy_service = described_class.new(
          merge_request: merge_request,
          violation_detail_data: {
            scan_result_policy_read.id => { 'full_newly_detected_uuids' => [uuid] }
          }
        )

        legacy_attrs = [{ scan_result_policy_id: scan_result_policy_read.id }]

        expect { legacy_service.execute(legacy_attrs) }.to change { detail.count }.by(1)
        expect(detail.last).to have_attributes(finding_uuid: uuid, finding_state: 'newly_detected',
          policy_rule_type: 'scan_finding', project_id: project.id)
      end

      it 'uses scan_result_policy_read.id as the violation_detail_data key in the legacy path' do
        commits = %w[sha1 sha2]
        legacy_service = described_class.new(
          merge_request: merge_request,
          violation_detail_data: {
            scan_result_policy_read.id => { 'full_commit_shas' => commits }
          }
        )

        legacy_attrs = [{ scan_result_policy_id: scan_result_policy_read.id }]
        legacy_service.execute(legacy_attrs)

        row = detail.any_merge_request.order(:id).last
        expect(row.total_commit_shas_count).to eq(commits.size)
      end
    end

    context 'when existing detail rows are replaced atomically' do
      let(:uuid_old) { SecureRandom.uuid }
      let(:uuid_new) { SecureRandom.uuid }

      it 'deletes old rows and inserts new ones in a transaction' do
        described_class.new(
          merge_request: merge_request,
          violation_detail_data: {
            policy_rule.id => { 'full_newly_detected_uuids' => [uuid_old] }
          }
        ).execute(attrs)

        expect(detail.pluck(:finding_uuid)).to contain_exactly(uuid_old)

        described_class.new(
          merge_request: merge_request,
          violation_detail_data: {
            policy_rule.id => { 'full_newly_detected_uuids' => [uuid_new] }
          }
        ).execute(attrs)

        expect(detail.pluck(:finding_uuid)).to contain_exactly(uuid_new)
      end
    end
  end
end
