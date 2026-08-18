# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::Restoration::RestoreForGroupService, :elastic, feature_category: :vulnerability_management do
  describe '.execute' do
    let_it_be_with_refind(:group) { create(:group) }
    let_it_be_with_refind(:project) { create(:project, group: group) }

    let!(:finding) { create(:vulnerabilities_finding, :skip_false_positive_detection, project: project) }
    let!(:vulnerability) { finding.vulnerability }
    let!(:evidence) { create_with_project(:vulnerabilties_finding_evidence, finding: finding) }
    let!(:flag) { create_with_project(:vulnerabilities_flag, finding: finding) }
    let!(:link) { create_with_project(:finding_link, finding: finding) }
    let!(:remediation) { create_with_project(:vulnerability_finding_remediation, finding: finding) }
    let!(:signature) { create_with_project(:vulnerabilities_finding_signature, finding: finding) }
    let!(:external_link) { create_with_project(:vulnerabilities_external_issue_link, vulnerability: vulnerability) }
    let!(:issue_link) { create_with_project(:vulnerabilities_issue_link, vulnerability: vulnerability) }
    let!(:mr_link) { create_with_project(:vulnerabilities_merge_request_link, vulnerability: vulnerability) }
    let!(:severity_override) { create_with_project(:vulnerability_severity_override, vulnerability: vulnerability) }
    let!(:state_transition) { create_with_project(:vulnerability_state_transition, vulnerability: vulnerability) }
    let!(:user_mention) { create_with_project(:vulnerability_user_mention, vulnerability: vulnerability) }
    let!(:identifier) { create_with_project(:vulnerabilities_finding_identifier, finding: finding) }
    let!(:vulnerability_read) { vulnerability.vulnerability_read }
    let!(:risk_score) { create(:vulnerability_finding_risk_score, finding: finding) }
    let(:previous_traversal_ids_value) { project.namespace.traversal_ids }

    before do
      set_elasticsearch_migration_to :create_vulnerability_reads_index, including: true

      sql = "SELECT * FROM vulnerability_occurrences WHERE id = ?"
      finding_sql = Vulnerabilities::Finding.sanitize_sql_array([sql, finding.id])
      finding_data = Vulnerabilities::Finding.connection.execute(finding_sql).to_a

      vulnerability_read.update_columns(traversal_ids: previous_traversal_ids_value)

      create_backup_records(Vulnerabilities::Finding.backup_model, finding_data)

      delete_and_create_backup_records_for(identifier)
      delete_and_create_backup_records_for(evidence)
      delete_and_create_backup_records_for(flag)
      delete_and_create_backup_records_for(link)
      delete_and_create_backup_records_for(remediation)
      delete_and_create_backup_records_for(signature)
      delete_and_create_backup_records_for(vulnerability_read)
      delete_and_create_backup_records_for(external_link)
      delete_and_create_backup_records_for(issue_link)
      delete_and_create_backup_records_for(mr_link)
      delete_and_create_backup_records_for(severity_override)
      delete_and_create_backup_records_for(state_transition)
      delete_and_create_backup_records_for(user_mention)
      delete_and_create_backup_records_for(vulnerability, extra: { traversal_ids: group.traversal_ids })

      finding.destroy!
    end

    subject(:restore) { described_class.execute(group) }

    it 'restores data from backup records' do
      expect { restore }.to change { Vulnerability.count }.by(1)
                        .and change { Vulnerabilities::Finding.count }.by(1)
                        .and change { Vulnerabilities::FindingIdentifier.count }.by(1)
                        .and change { Vulnerabilities::Finding::Evidence.count }.by(1)
                        .and change { Vulnerabilities::Flag.count }.by(1)
                        .and change { Vulnerabilities::FindingLink.count }.by(1)
                        .and change { Vulnerabilities::FindingRemediation.count }.by(1)
                        .and change { Vulnerabilities::FindingSignature.count }.by(1)
                        .and change { Vulnerabilities::ExternalIssueLink.count }.by(1)
                        .and change { Vulnerabilities::IssueLink.count }.by(1)
                        .and change { Vulnerabilities::MergeRequestLink.count }.by(1)
                        .and change { Vulnerabilities::SeverityOverride.count }.by(1)
                        .and change { Vulnerabilities::StateTransition.count }.by(1)
                        .and change { VulnerabilityUserMention.count }.by(1)
                        .and change { Vulnerabilities::Read.count }.by(1)
                        .and change { Vulnerabilities::FindingRiskScore.count }.by(1)
    end

    it 'deletes the backups' do
      expect { restore }.to change { Vulnerabilities::Backups::Finding.count }.by(-1)
                        .and change { Vulnerabilities::Backups::FindingEvidence.count }.by(-1)
                        .and change { Vulnerabilities::Backups::FindingFlag.count }.by(-1)
                        .and change { Vulnerabilities::Backups::FindingIdentifier.count }.by(-1)
                        .and change { Vulnerabilities::Backups::FindingLink.count }.by(-1)
                        .and change { Vulnerabilities::Backups::FindingRemediation.count }.by(-1)
                        .and change { Vulnerabilities::Backups::FindingSignature.count }.by(-1)
                        .and change { Vulnerabilities::Backups::Vulnerability.count }.by(-1)
                        .and change { Vulnerabilities::Backups::VulnerabilityExternalIssueLink.count }.by(-1)
                        .and change { Vulnerabilities::Backups::VulnerabilityIssueLink.count }.by(-1)
                        .and change { Vulnerabilities::Backups::VulnerabilityMergeRequestLink.count }.by(-1)
                        .and change { Vulnerabilities::Backups::VulnerabilityRead.count }.by(-1)
                        .and change { Vulnerabilities::Backups::VulnerabilitySeverityOverride.count }.by(-1)
                        .and change { Vulnerabilities::Backups::VulnerabilityStateTransition.count }.by(-1)
                        .and change { Vulnerabilities::Backups::VulnerabilityUserMention.count }.by(-1)
    end

    it 'restores the data correctly' do
      expect do
        restore

        finding.reload
        vulnerability.reload
        identifier.reload
        evidence.reload
        flag.reload
        link.reload
        remediation.reload
        signature.reload
        external_link.reload
        issue_link.reload
        mr_link.reload
        severity_override.reload
        state_transition.reload
        user_mention.reload
        vulnerability_read.reload
        risk_score.reload
      end.to not_change { finding.as_json }
         .and not_change { vulnerability.as_json(except: :updated_at) }
         .and not_change { identifier.as_json }
         .and not_change { evidence.as_json }
         .and not_change { flag.as_json }
         .and not_change { link.as_json }
         .and not_change { remediation.as_json }
         .and not_change { signature.as_json }
         .and not_change { external_link.as_json }
         .and not_change { issue_link.as_json }
         .and not_change { mr_link.as_json }
         .and not_change { severity_override.as_json }
         .and not_change { state_transition.as_json }
         .and not_change { user_mention.as_json }
         .and not_change { vulnerability_read.as_json }
         .and not_change { risk_score.as_json(except: [:created_at, :updated_at]) }
    end

    it 'changes the `updated_at` value of vulnerabilities' do
      travel_to 3.days.from_now do
        expect do
          restore

          vulnerability.reload
        end.to change { vulnerability.updated_at }.to(Time.zone.now)
      end
    end

    it_behaves_like 'sync vulnerabilities changes to ES' do
      let(:expected_vulnerabilities) { [vulnerability.vulnerability_read] }
    end

    context 'when the owner project moves to a different group' do
      let(:previous_traversal_ids_value) { [non_existing_record_id] }

      it 'adjusts the `traversal_ids` attribute of `vulnerability_reads` records' do
        expect do
          restore

          vulnerability_read.reload
        end.to change { vulnerability_read.traversal_ids }.from(previous_traversal_ids_value)
                                                          .to(project.namespace.traversal_ids)
      end
    end

    context 'when the project gets archived after the backups created' do
      before do
        project.update_column(:archived, true)
      end

      it 'adjusts the `archived` attribute of `vulnerability_reads` records' do
        expect do
          restore

          vulnerability_read.reload
        end.to change { vulnerability_read.archived }.from(false).to(true)
      end
    end

    context 'when an exception occurs while restoring the data' do
      let(:expected_exception) { RuntimeError.new }

      before do
        allow(Vulnerabilities::Archival::Restoration::Tasks::RestoreVulnerabilities)
          .to receive(:execute).and_raise(expected_exception)
      end

      it 'propagates the error' do
        expect { restore }.to raise_error(expected_exception)
      end

      describe 'logging' do
        let(:log_payload) { { class_name: 'Vulnerabilities::Archival::Restoration::RestoreBatchService' } }

        before do
          allow(Gitlab::ErrorTracking).to receive(:log_and_raise_exception)
        end

        it 'logs the error' do
          restore

          expect(Gitlab::ErrorTracking)
            .to have_received(:log_and_raise_exception).with(expected_exception, log_payload)
        end
      end
    end

    context 'when there is a finding with the same UUID on live table' do
      let!(:finding_not_deleted) { create(:vulnerabilities_finding, :detected, project: project) }

      before do
        sql = "SELECT * FROM vulnerability_occurrences WHERE id = ?"
        finding_sql = Vulnerabilities::Finding.sanitize_sql_array([sql, finding_not_deleted.id])
        finding_data = Vulnerabilities::Finding.connection.execute(finding_sql).to_a

        create_backup_records(Vulnerabilities::Finding.backup_model, finding_data)
      end

      it 'does not raise an exception' do
        expect { restore }.not_to raise_error
      end

      it 'restores non conflicting findings' do
        expect { restore }.to change { Vulnerabilities::Finding.count }.by(1)
      end
    end

    context 'when a project is transfered while running the logic' do
      let(:task_class) { Vulnerabilities::Archival::Restoration::Tasks::AdjustTraversalIdsAndArchivedAttributes }

      before do
        allow_next_instance_of(task_class) do |instance|
          allow(instance).to receive(:update_vulnerability_reads).and_wrap_original do |original|
            original.call

            allow_cross_database_modification_within_transaction(
              url: 'https://gitlab.com/gitlab-org/gitlab/-/merge_requests/206231'
            ) do
              group.update_column(:traversal_ids, [non_existing_record_id])
            end
          end
        end

        allow(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker).to receive(:perform_async)
      end

      it 'schedules `UpdateNamespaceIdsOfVulnerabilityReadsWorker`' do
        restore

        expect(Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker)
          .to have_received(:perform_async).with(project.id)
      end
    end

    context 'when a project is archived while running the logic', :sidekiq_inline do
      let(:task_class) { Vulnerabilities::Archival::Restoration::Tasks::AdjustTraversalIdsAndArchivedAttributes }

      before do
        allow_next_instance_of(task_class) do |instance|
          allow(instance).to receive(:update_vulnerability_reads).and_wrap_original do |original|
            original.call

            allow_cross_database_modification_within_transaction(
              url: 'https://gitlab.com/gitlab-org/gitlab/-/merge_requests/206231'
            ) do
              project.update_column(:archived, true)
            end
          end
        end

        project.project_setting.has_vulnerabilities = true
        project.project_setting.save!

        allow(Vulnerabilities::UpdateArchivedOfVulnerabilityReadsService).to receive(:execute)
      end

      it 'schedules `ProcessArchivedEventsWorker`' do
        restore

        expect(Vulnerabilities::UpdateArchivedOfVulnerabilityReadsService).to have_received(:execute).with(project.id)
      end
    end

    describe 'logging' do
      let(:log_payload) do
        {
          batch_size: 1,
          class_name: 'Vulnerabilities::Archival::Restoration::RestoreBatchService',
          message: 'Batch of vulnerabilities are restored',
          restored_vulnerability_count: 1
        }
      end

      before do
        allow(Gitlab::AppLogger).to receive(:info)
      end

      it 'logs the information' do
        restore

        expect(Gitlab::AppLogger).to have_received(:info).with(log_payload)
      end
    end

    describe 'adjusting the archive records' do
      let!(:archive) { create(:vulnerability_archive, archived_records_count: 1) }
      let!(:archived_record) do
        create(:vulnerability_archived_record, vulnerability_identifier: vulnerability.id, archive: archive)
      end

      it 'removes the `archived_record`' do
        expect { restore }.to change { Vulnerabilities::ArchivedRecord.exists?(archived_record.id) }.to(false)
      end

      it 'updates the `archived_records_count` attribute' do
        expect { restore }.to change { archive.reload.archived_records_count }.by(-1)
      end
    end

    describe 'partition reading' do
      before do
        skip_if_shared_database(:sec)

        ApplicationRecord.connection.execute("DROP TABLE backup_vulnerabilities")
        Ci::ApplicationRecord.connection.execute("DROP TABLE backup_vulnerabilities")
      end

      it 'uses the correct database connection while reading data from partitions directly' do
        expect { restore }.to change { Vulnerability.count }.by(1)
      end
    end

    def create_with_project(factory, **extra)
      create(factory, **extra, project_id: project.id)
    end

    def delete_and_create_backup_records_for(record, extra: {})
      returned_data = record.class.primary_key_in(record).delete_all_returning

      create_backup_records(record.class.backup_model, returned_data, extra: extra)
    end

    def create_backup_records(backup_model, data, extra: {})
      Vulnerabilities::Removal::BackupService.execute(
        backup_model,
        Time.current,
        data,
        extra: extra
      )
    end
  end
end
