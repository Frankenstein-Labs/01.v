# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Archival::ArchiveBatchService, feature_category: :vulnerability_management do
  describe '.execute' do
    let(:mock_project) { instance_double(Project) }
    let(:batch) { [] }
    let(:mock_service_object) { instance_spy(described_class) }

    subject(:execute_archive_batch_logic) { described_class.execute(mock_project, batch) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates an object and delegates the call to it' do
      execute_archive_batch_logic

      expect(described_class).to have_received(:new).with(mock_project, batch)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let_it_be_with_refind(:project) { create(:project) }
    let_it_be_with_refind(:archive) { create(:vulnerability_archive, project: project) }
    let_it_be_with_refind(:vulnerability) { create(:vulnerability, project: project) }
    let_it_be(:archived_record) do
      build(:vulnerability_archived_record,
        archive: archive,
        project: project,
        vulnerability_identifier: vulnerability.id,
        created_at: Time.zone.now,
        updated_at: Time.zone.now)
    end

    let(:service_object) { described_class.new(archive, project.vulnerabilities) }

    subject(:archive_vulnerabilities) { service_object.execute }

    before do
      # This is messed up. Both vulnerability and finding records have foreign keys to each other.
      # This will be fixed by tracking vulnerabilities on multiple branches effort.
      vulnerability.vulnerability_finding.update_column(:vulnerability_id, vulnerability.id)

      allow(Vulnerabilities::Archival::ArchivedRecordBuilderService).to receive(:execute).and_return(archived_record)
      allow(Vulnerabilities::Statistics::AdjustmentWorker).to receive(:perform_async)
    end

    it 'archives the vulnerabilities' do
      expect { archive_vulnerabilities }.to change { Vulnerability.exists?(vulnerability.id) }.to(false)
                                        .and change { archive.archived_records.count }.by(1)
                                        .and change { archive.reload.archived_records_count }.by(1)
    end

    it 'schedules the statistics adjustment worker' do
      archive_vulnerabilities

      expect(Vulnerabilities::Statistics::AdjustmentWorker).to have_received(:perform_async).with([project.id])
    end

    context 'when the archived record data contains unicode null character' do
      let(:archived_record) do
        build(:vulnerability_archived_record,
          :with_unicode_null_character,
          archive: archive,
          project: project,
          vulnerability_identifier: vulnerability.id,
          created_at: Time.zone.now,
          updated_at: Time.zone.now)
      end

      it 'archives the vulnerabilities' do
        expect { archive_vulnerabilities }.to change { Vulnerability.exists?(vulnerability.id) }.to(false)
                                          .and change { archive.archived_records.count }.by(1)
                                          .and change { archive.reload.archived_records_count }.by(1)
      end
    end

    describe 'preloading the associations' do
      before do
        allow(Vulnerabilities::Archival::ArchivedRecordBuilderService).to receive(:execute).and_call_original
      end

      it 'does not cause N+1 query issues' do
        control = ActiveRecord::QueryRecorder.new { described_class.new(archive, project.vulnerabilities).execute }

        another_vulnerability_1 = create(:vulnerability, project: project)
        another_vulnerability_1.vulnerability_finding.update_column(:vulnerability_id, another_vulnerability_1.id)

        another_vulnerability_2 = create(:vulnerability, project: project)
        another_vulnerability_2.vulnerability_finding.update_column(:vulnerability_id, another_vulnerability_2.id)

        expect { described_class.new(archive, project.vulnerabilities).execute }.not_to exceed_query_limit(control)
      end
    end

    describe 'taking backup' do
      let_it_be(:finding) { vulnerability.vulnerability_finding }
      let_it_be(:evidence) { create(:vulnerabilties_finding_evidence, finding: finding) }
      let_it_be(:flag) { create(:vulnerabilities_flag, finding: finding) }
      let_it_be(:link) { create(:finding_link, finding: finding) }
      let_it_be(:remediation) { create(:vulnerability_finding_remediation, finding: finding) }
      let_it_be(:signature) { create(:vulnerabilities_finding_signature, finding: finding) }

      let_it_be(:external_issue_link) { create(:vulnerabilities_external_issue_link, vulnerability: vulnerability) }
      let_it_be(:issue_link) { create(:vulnerabilities_issue_link, vulnerability: vulnerability) }
      let_it_be(:merge_request_link) { create(:vulnerabilities_merge_request_link, vulnerability: vulnerability) }
      let_it_be(:severity_override) { create(:vulnerability_severity_override, vulnerability: vulnerability) }
      let_it_be(:state_transition) { create(:vulnerability_state_transition, vulnerability: vulnerability) }
      let_it_be(:user_mention) { create(:vulnerability_user_mention, vulnerability: vulnerability) }

      before do
        finding.identifiers << finding.primary_identifier
      end

      it 'creates backup records' do
        expect { archive_vulnerabilities }.to change { backup_record_of(finding) }.from(nil)
                                          .and change { backup_record_of(evidence) }.from(nil)
                                          .and change { backup_record_of(flag) }.from(nil)
                                          .and change { backup_record_of(link) }.from(nil)
                                          .and change { backup_record_of(remediation) }.from(nil)
                                          .and change { backup_record_of(signature) }.from(nil)
                                          .and change { backup_record_of(vulnerability) }.from(nil)
                                          .and change { backup_record_of(external_issue_link) }.from(nil)
                                          .and change { backup_record_of(issue_link) }.from(nil)
                                          .and change { backup_record_of(merge_request_link) }.from(nil)
                                          .and change { backup_record_of(severity_override) }.from(nil)
                                          .and change { backup_record_of(state_transition) }.from(nil)
                                          .and change { backup_record_of(user_mention) }.from(nil)
      end

      it 'assigns `traversal_ids` to vulnerability backup' do
        archive_vulnerabilities

        backup_record = Vulnerabilities::Backups::Vulnerability.find_by(original_record_identifier: vulnerability.id)

        expect(backup_record.traversal_ids).to eq(project.namespace.traversal_ids)
      end

      def backup_record_of(record)
        record.class.backup_model.find_by(original_record_identifier: record)
      end
    end
  end
end
