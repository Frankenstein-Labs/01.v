# frozen_string_literal: true

RSpec.shared_examples 'header creation validation errors' do
  let(:expected_errors) { ["Key can't be blank", "Value can't be blank", "Active must be a boolean value"] }

  it 'has an array of errors in the response' do
    expect(response).to be_error
    expect(response.errors).to match_array expected_errors
  end
end

RSpec.shared_examples 'does not create audit event' do
  it do
    expect { response }.to not_change { AuditEventReader.count }
  end
end

RSpec.shared_examples 'header creation successful' do
  it 'has the header in the response payload' do
    expect(response).to be_success
    expect(response.payload[:header].key).to eq 'a_key'
    expect(response.payload[:header].value).to eq 'a_value'
  end

  it 'creates header for destination' do
    expect { response }
      .to change { destination.headers.count }.by(1)

    destination.headers.reload
    header = destination.headers.last

    expect(header.key).to eq('a_key')
    expect(header.value).to eq('a_value')
  end

  context "with license feature external_audit_events" do
    before do
      stub_licensed_features(external_audit_events: true)
      create(:audit_events_instance_external_streaming_destination)
    end

    it 'sends correct event type in audit event stream' do
      expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(event_type, nil, anything)

      response
    end
  end
end

RSpec.shared_examples 'header updation' do
  context 'when header updation is successful' do
    it 'has the header in the response payload' do
      expect(response).to be_success
      expect(response.payload[:header].key).to eq 'new'
      expect(response.payload[:header].value).to eq 'new'
    end

    it 'updates the header' do
      expect(response).to be_success
      expect(header.reload.key).to eq 'new'
      expect(header.value).to eq 'new'
    end

    context 'with audit events' do
      it 'sends the audit streaming event' do
        audit_context = {
          name: event_type,
          author: user,
          scope: audit_scope,
          target: header,
          target_details: "new",
          message: "Updated a custom HTTP header from key old to have a key new to have a new value activation " \
                   "status changed to false.",
          additional_details: {
            "active" => [true, false],
            "key" => %w[old new],
            "value" => %w[old new]
          }
        }

        audit_context = audit_context.merge(extra_audit_context)

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).and_call_original
        expect { response }.to change { AuditEventReader.count }.from(0).to(1)
      end

      context "with license feature external_audit_events" do
        before do
          stub_licensed_features(external_audit_events: true)
          create(:audit_events_instance_external_streaming_destination)
        end

        context 'when both key and value are updated' do
          it 'creates audit event' do
            expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(event_type, nil, anything)

            response
          end
        end
      end

      context 'when only the header value is updated' do
        let(:params) { super().slice(:header, :value) }

        it 'has a audit message reflecting just the value was changed' do
          audit_context = {
            name: event_type,
            author: user,
            scope: audit_scope,
            target: header,
            target_details: "old",
            message: "Updated a custom HTTP header with key old to have a new value.",
            additional_details: {
              "value" => %w[old new]
            }
          }

          audit_context = audit_context.merge(extra_audit_context)

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)
          response
        end
      end

      context 'when only the active attribute is updated' do
        let(:params) { super().slice(:header, :active) }

        it 'has a audit message reflecting just the active attribute was changed' do
          audit_context = {
            name: event_type,
            author: user,
            scope: audit_scope,
            target: header,
            target_details: "old",
            message: "Updated a custom HTTP header with key old activation status changed to false.",
            additional_details: {
              "active" => [true, false]
            }
          }

          audit_context = audit_context.merge(extra_audit_context)

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)
          response
        end
      end

      context 'when neither key, value nor active is updated' do
        let(:params) { super().merge(key: 'old', value: 'old', active: true) }

        it_behaves_like 'does not create audit event'
      end
    end
  end

  context 'when header updation is unsuccessful' do
    let(:params) do
      {
        header: header,
        key: '',
        value: 'new',
        active: false
      }
    end

    it 'does not update the header' do
      expect { subject }.not_to change { header.reload.key }
      expect(header.value).to eq 'old'
    end

    it 'has an error response' do
      expect(response).to be_error
      expect(response.errors)
        .to match_array ["Key can't be blank"]
    end

    it_behaves_like 'does not create audit event'
  end
end

RSpec.shared_examples 'header deletion' do
  context 'when deletion is successful' do
    it 'destroys the header' do
      expect { response }.to change { destination.headers.count }.by(-1)
      expect(response).to be_success
    end

    context 'with audit events' do
      it 'sends the audit streaming event' do
        audit_context = {
          name: event_type,
          author: user,
          scope: audit_scope,
          target: header,
          target_details: header.key,
          message: "Destroyed a custom HTTP header with key #{header.key}.",
          additional_details: {}
        }

        audit_context = audit_context.merge(extra_audit_context)

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).and_call_original
        expect { response }.to change { AuditEventReader.count }.from(0).to(1)
      end

      context "with license feature external_audit_events" do
        before do
          stub_licensed_features(external_audit_events: true)
          create(:audit_events_instance_external_streaming_destination)
        end

        it 'sends correct event type in audit event stream' do
          expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(event_type, nil, anything)

          response
        end
      end
    end
  end

  context 'when deletion is unsuccessful' do
    before do
      allow(header).to receive(:destroy).and_return(false)
      allow(header).to receive(:errors).and_return('foo')
    end

    it 'does not destroy the header' do
      expect { service.execute }.not_to change { destination.headers.count }
    end

    it 'has an error response' do
      response = service.execute

      expect(response).to be_error
      expect(response.errors)
        .to match_array ['foo']
    end

    it_behaves_like 'does not create audit event'
  end
end
