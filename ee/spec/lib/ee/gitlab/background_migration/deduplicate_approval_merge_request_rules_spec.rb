# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- BBM specs require extensive setup
RSpec.describe Gitlab::BackgroundMigration::DeduplicateApprovalMergeRequestRules, feature_category: :security_policy_management do
  let(:connection) { ApplicationRecord.connection }

  let(:organizations) { table(:organizations) }
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:users) { table(:users) }
  let(:merge_requests) { table(:merge_requests) }
  let(:approval_merge_request_rules) { table(:approval_merge_request_rules) }
  let(:security_orchestration_policy_configurations) { table(:security_orchestration_policy_configurations) }

  let(:organization) { organizations.create!(name: 'org', path: 'org') }
  let(:namespace) { namespaces.create!(name: 'ns', path: 'ns', organization_id: organization.id, type: 'Group') }

  let(:project_namespace) do
    namespaces.create!(name: 'test', path: 'test', organization_id: organization.id, type: 'Project')
  end

  let(:project) do
    projects.create!(
      name: 'test',
      path: 'test',
      namespace_id: namespace.id,
      project_namespace_id: project_namespace.id,
      organization_id: organization.id
    )
  end

  let(:user) do
    users.create!(
      username: 'test',
      email: 'test@example.com',
      projects_limit: 10,
      organization_id: organization.id
    )
  end

  let(:merge_request) do
    merge_requests.create!(
      target_project_id: project.id,
      target_branch: 'main',
      source_branch: 'feature',
      author_id: user.id
    )
  end

  let(:policy_project_namespace) do
    namespaces.create!(name: 'policy', path: 'policy', organization_id: organization.id, type: 'Project')
  end

  let(:policy_project) do
    projects.create!(
      name: 'policy',
      path: 'policy',
      namespace_id: namespace.id,
      project_namespace_id: policy_project_namespace.id,
      organization_id: organization.id
    )
  end

  let(:policy_configuration) do
    security_orchestration_policy_configurations.create!(
      project_id: project.id,
      security_policy_management_project_id: policy_project.id
    )
  end

  let(:rule_type_report_approver) { 3 }
  let(:report_type_scan_finding) { 4 }
  let(:report_type_any_merge_request) { 5 }
  let(:report_type_license_scanning) { 2 }
  let(:report_type_code_coverage) { 1 }

  let(:base_attributes) do
    {
      merge_request_id: merge_request.id,
      name: 'Test Rule',
      rule_type: rule_type_report_approver,
      report_type: report_type_scan_finding,
      section: nil,
      security_orchestration_policy_configuration_id: policy_configuration.id,
      orchestration_policy_idx: 0,
      approval_policy_action_idx: 0,
      approvals_required: 1
    }
  end

  let(:start_id) { approval_merge_request_rules.minimum(:id) || 1 }
  let(:end_id) { approval_merge_request_rules.maximum(:id) || 1 }

  let(:migration) do
    described_class.new(
      connection: connection,
      start_id: start_id,
      end_id: end_id,
      batch_table: :approval_merge_request_rules,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      job_arguments: []
    )
  end

  subject(:perform) { migration.perform }

  describe '#perform' do
    context 'with duplicate scan result policy rules' do
      let!(:older_rule) do
        approval_merge_request_rules.create!(
          base_attributes.merge(
            created_at: 2.days.ago,
            updated_at: 2.days.ago
          )
        )
      end

      let!(:newer_rule) do
        approval_merge_request_rules.create!(
          base_attributes.merge(
            created_at: 1.day.ago,
            updated_at: 1.day.ago
          )
        )
      end

      it 'deletes the older duplicate' do
        expect { perform }.to change { approval_merge_request_rules.count }.from(2).to(1)
      end

      it 'keeps the rule with the highest id', :aggregate_failures do
        perform

        expect(approval_merge_request_rules.exists?(newer_rule.id)).to be(true)
        expect(approval_merge_request_rules.exists?(older_rule.id)).to be(false)
      end
    end

    context 'with rules differing by uniqueness columns' do
      let!(:rule_policy_idx_0) do
        approval_merge_request_rules.create!(
          base_attributes.merge(orchestration_policy_idx: 0)
        )
      end

      let!(:rule_policy_idx_1) do
        approval_merge_request_rules.create!(
          base_attributes.merge(orchestration_policy_idx: 1)
        )
      end

      it 'does not delete rules with different uniqueness keys' do
        expect { perform }.not_to change { approval_merge_request_rules.count }.from(2)
      end
    end

    context 'with non-policy report types' do
      let!(:code_coverage_rule_1) do
        approval_merge_request_rules.create!(
          base_attributes.merge(
            report_type: report_type_code_coverage,
            name: 'Coverage Rule',
            updated_at: 2.days.ago
          )
        )
      end

      let!(:code_coverage_rule_2) do
        approval_merge_request_rules.create!(
          base_attributes.merge(
            report_type: report_type_code_coverage,
            name: 'Coverage Rule',
            updated_at: 1.day.ago
          )
        )
      end

      it 'does not delete non-policy duplicates' do
        expect { perform }.not_to change { approval_merge_request_rules.count }.from(2)
      end
    end

    context 'with all three policy report types' do
      let!(:scan_finding_old) do
        approval_merge_request_rules.create!(
          base_attributes.merge(
            report_type: report_type_scan_finding,
            updated_at: 2.days.ago
          )
        )
      end

      let!(:scan_finding_new) do
        approval_merge_request_rules.create!(
          base_attributes.merge(
            report_type: report_type_scan_finding,
            updated_at: 1.day.ago
          )
        )
      end

      let!(:license_scanning_old) do
        approval_merge_request_rules.create!(
          base_attributes.merge(
            report_type: report_type_license_scanning,
            name: 'License Rule',
            updated_at: 2.days.ago
          )
        )
      end

      let!(:license_scanning_new) do
        approval_merge_request_rules.create!(
          base_attributes.merge(
            report_type: report_type_license_scanning,
            name: 'License Rule',
            updated_at: 1.day.ago
          )
        )
      end

      let!(:any_mr_old) do
        approval_merge_request_rules.create!(
          base_attributes.merge(
            report_type: report_type_any_merge_request,
            name: 'Any MR Rule',
            updated_at: 2.days.ago
          )
        )
      end

      let!(:any_mr_new) do
        approval_merge_request_rules.create!(
          base_attributes.merge(
            report_type: report_type_any_merge_request,
            name: 'Any MR Rule',
            updated_at: 1.day.ago
          )
        )
      end

      it 'deduplicates all three report types' do
        expect { perform }.to change { approval_merge_request_rules.count }.from(6).to(3)
      end

      it 'keeps the newest rule for each report type', :aggregate_failures do
        perform

        expect(approval_merge_request_rules.exists?(scan_finding_new.id)).to be(true)
        expect(approval_merge_request_rules.exists?(license_scanning_new.id)).to be(true)
        expect(approval_merge_request_rules.exists?(any_mr_new.id)).to be(true)
      end
    end

    context 'with no duplicates' do
      let!(:unique_rule) do
        approval_merge_request_rules.create!(base_attributes)
      end

      it 'does not delete anything' do
        expect { perform }.not_to change { approval_merge_request_rules.count }.from(1)
      end
    end

    context 'with empty table' do
      it 'does not raise an error' do
        expect { perform }.not_to raise_error
      end
    end

    context 'with rules that have a non-null section' do
      let!(:rule_with_section) do
        approval_merge_request_rules.create!(
          base_attributes.merge(section: 'Documentation')
        )
      end

      let!(:rule_without_section) do
        approval_merge_request_rules.create!(
          base_attributes.merge(section: nil, name: 'Other Rule')
        )
      end

      it 'deletes rules with non-null section' do
        expect { perform }.to change { approval_merge_request_rules.count }.from(2).to(1)
      end

      it 'keeps only the rule without section', :aggregate_failures do
        perform

        expect(approval_merge_request_rules.exists?(rule_with_section.id)).to be(false)
        expect(approval_merge_request_rules.exists?(rule_without_section.id)).to be(true)
      end
    end

    context 'when duplicates are scattered across sections' do
      let!(:rule_with_section) do
        approval_merge_request_rules.create!(
          base_attributes.merge(section: 'Backend')
        )
      end

      let!(:duplicate_old) do
        approval_merge_request_rules.create!(
          base_attributes.merge(section: nil, created_at: 2.days.ago)
        )
      end

      let!(:duplicate_new) do
        approval_merge_request_rules.create!(
          base_attributes.merge(section: nil, created_at: 1.day.ago)
        )
      end

      it 'deletes rules with section and deduplicates the rest' do
        expect { perform }.to change { approval_merge_request_rules.count }.from(3).to(1)
      end

      it 'keeps only the newest duplicate without section', :aggregate_failures do
        perform

        expect(approval_merge_request_rules.exists?(rule_with_section.id)).to be(false)
        expect(approval_merge_request_rules.exists?(duplicate_old.id)).to be(false)
        expect(approval_merge_request_rules.exists?(duplicate_new.id)).to be(true)
      end
    end

    context 'with duplicates having widely separated IDs' do
      let(:sub_batch_size) { 2 }

      let(:migration) do
        described_class.new(
          connection: connection,
          start_id: start_id,
          end_id: end_id,
          batch_table: :approval_merge_request_rules,
          batch_column: :id,
          sub_batch_size: sub_batch_size,
          pause_ms: 0,
          job_arguments: []
        )
      end

      let!(:rule_low_id) do
        approval_merge_request_rules.create!(base_attributes)
      end

      let!(:unrelated_rule) do
        approval_merge_request_rules.create!(base_attributes.merge(name: 'Unrelated Rule'))
      end

      let!(:rule_high_id) do
        approval_merge_request_rules.create!(base_attributes)
      end

      it 'deduplicates across sub-batch boundaries' do
        expect { perform }.to change { approval_merge_request_rules.count }.from(3).to(2)
      end

      it 'keeps the rule with highest id and the unrelated rule', :aggregate_failures do
        perform

        expect(approval_merge_request_rules.exists?(rule_low_id.id)).to be(false)
        expect(approval_merge_request_rules.exists?(unrelated_rule.id)).to be(true)
        expect(approval_merge_request_rules.exists?(rule_high_id.id)).to be(true)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
