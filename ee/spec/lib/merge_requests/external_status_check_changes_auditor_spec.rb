# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ExternalStatusCheckChangesAuditor, feature_category: :code_review_workflow do
  describe 'auditing external status check changes' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be_with_reload(:external_status_check) do
      create(
        :external_status_check,
        name: 'QA',
        external_url: 'http://examplev1.com',
        project: project
      )
    end

    # `freeze: false` is required here: this auditor is a PORO that captures
    # the status check state and is exercised across examples; freezing it
    # raises FrozenError and reload/refind are no-ops on it. Keep as-is (see
    # gitlab-org/gitlab#602925).
    let_it_be(:external_status_check_changes_auditor, freeze: false) do
      described_class.new(
        user, external_status_check)
    end

    before do
      stub_licensed_features(audit_events: true, extended_audit_events: true)
      stub_licensed_features(external_audit_events: true)
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    subject { described_class.new(user, project.external_status_checks) }

    context 'when audit change happens' do
      it 'creates an event when the name changes' do
        external_status_check.update!(name: 'QAv2')

        expect { external_status_check_changes_auditor.execute }
          .to change { AuditEventReader.count }.by(1)

        expect(AuditEventReader.last.details).to include({ change: 'name', from: 'QA', to: 'QAv2' })
      end

      it 'creates an event when the external url changes' do
        external_status_check.update!(external_url: 'http://examplev2.com')

        expect { external_status_check_changes_auditor.execute }
          .to change { AuditEventReader.count }.by(1)

        expect(AuditEventReader.last.details).to include(
          {
            change: 'external url',
            from: 'http://examplev1.com',
            to: 'http://examplev2.com'
          })
      end

      it 'streams audit event when name changes', :aggregate_failures do
        external_status_check.update!(name: 'QAv3')

        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)
          .with('external_status_check_name_updated', any_args)

        external_status_check_changes_auditor.execute
      end

      it 'streams audit event when url changes', :aggregate_failures do
        external_status_check.update!(external_url: 'http://examplev3.com')

        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)
          .with('external_status_check_url_updated', any_args)

        external_status_check_changes_auditor.execute
      end
    end

    context 'when there is no audit change' do
      it 'does not create audit event if no change in updated values' do
        external_status_check.update!(
          name: external_status_check.name,
          external_url: external_status_check.external_url
        )

        expect { external_status_check_changes_auditor.execute }
          .not_to change { AuditEventReader.count }
      end
    end
  end
end
