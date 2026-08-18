# frozen_string_literal: true

RSpec.shared_examples 'sends streaming audit event' do
  before do
    stub_licensed_features(external_audit_events: true)
    create(:audit_events_group_external_streaming_destination, group: group.root_ancestor)
  end

  it 'sends the audit streaming event' do
    expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).once

    subject
  end
end
