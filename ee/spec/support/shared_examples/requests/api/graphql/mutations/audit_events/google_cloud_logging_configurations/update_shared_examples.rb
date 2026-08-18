# frozen_string_literal: true

RSpec.shared_examples 'a mutation that does not update the google cloud logging configuration' do
  it 'does not update the configuration' do
    expect { mutate }.not_to change { config.reload.attributes }
  end

  it 'does not create audit event' do
    expect { mutate }.not_to change { AuditEventReader.count }
  end
end

RSpec.shared_examples 'entity owner updating google cloud logging configuration' do
  before do
    config.deactivate!
  end

  it 'updates the configuration' do
    mutate

    config.reload

    expect(config.google_project_id_name).to eq(updated_google_project_id_name)
    expect(config.client_email).to eq(updated_client_email)
    expect(config.private_key).to eq(updated_private_key)
    expect(config.log_id_name).to eq(updated_log_id_name)
    expect(config.name).to eq(updated_destination_name)
    expect(config.active).to be(true)
  end

  it 'audits the update' do
    Mutations::AuditEvents::GoogleCloudLoggingConfigurations::CommonUpdate::AUDIT_EVENT_COLUMNS.each do |column|
      message = if column == :private_key
                  "Changed #{column}"
                else
                  "Changed #{column} from #{config[column]} to #{input[column.to_s.camelize(:lower).to_sym]}"
                end

      expected_hash = {
        name: audit_event_name,
        author: current_user,
        scope: audit_scope,
        target: config,
        message: message
      }

      expect(Gitlab::Audit::Auditor).to receive(:audit).once.ordered.with(hash_including(expected_hash))
    end

    subject
  end

  context 'when the fields are updated with existing values' do
    let(:input) do
      {
        id: config_gid,
        googleProjectIdName: config.google_project_id_name,
        name: config.name,
        active: config.active
      }
    end

    it 'does not audit the event' do
      expect(Gitlab::Audit::Auditor).not_to receive(:audit)

      subject
    end
  end

  context 'when no fields are provided for update' do
    let(:input) do
      {
        id: config_gid
      }
    end

    it_behaves_like 'a mutation that does not update the google cloud logging configuration'
  end
end
