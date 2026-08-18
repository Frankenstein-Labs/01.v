# frozen_string_literal: true

RSpec.shared_examples_for 'create external status services' do
  context 'when parameters are invalid' do
    let(:params) { { external_url: 'external_url.text/hello.json', name: 'test' } }

    it 'is unsuccessful' do
      expect(execute.success?).to be false # execute is the named subject of the of the executed service
    end

    it 'does not create a new external status check' do
      expect { execute }.not_to change { MergeRequests::ExternalStatusCheck.count }
    end
  end

  context 'when user is not permitted to create external status checks' do
    let(:user) { create(:user, developer_of: project) }

    it 'is unsuccessful' do
      expect(execute.error?).to be true
    end

    it 'does not create a new external status check' do
      expect { execute }.not_to change { MergeRequests::ExternalStatusCheck.count }
    end

    it 'responds with the expected errors' do
      expect(execute.message).to eq('Failed to create external status check')
      expect(execute.payload[:errors]).to contain_exactly 'Not allowed'
    end
  end

  context 'when external status check is created successfully' do
    it 'creates a new MergeRequests::ExternalStatusCheck' do
      expect { execute }.to change { MergeRequests::ExternalStatusCheck.count }.by(1)
    end

    it 'is successful' do
      expect(execute.success?).to be true
    end

    it 'includes the newly created external status check in its payload' do
      external_status_check = execute.payload[:external_status_check]

      expect(external_status_check).to be_a(MergeRequests::ExternalStatusCheck)
      expect(external_status_check.project).to eq(project)
      expect(external_status_check.external_url).to eq('https://external_url.text/hello.json')
      expect(external_status_check.name).to eq 'Test'
      expect(external_status_check.shared_secret).to eq 'shared_secret'

      expect(external_status_check.protected_branches)
        .to(protected_branch ? contain_exactly(protected_branch) : be_empty)
    end
  end

  describe 'audit events' do
    context 'when licensed' do
      before do
        stub_licensed_features(audit_events: true)
      end

      context 'when external status check save operation succeeds', :request_store do
        it 'logs an audit event' do
          expect { execute }.to change { AuditEventReader.count }.by(1)
          message_suffix = protected_branch.present? ? "protected branch(es) #{protected_branch.name}" : "all branches"
          expect(AuditEventReader.last.details).to include(
            { custom_message: "Added Test status check with #{message_suffix}" }
          )
        end
      end

      context 'when external status check save operation fails' do
        before do
          allow(::MergeRequests::ExternalStatusCheck).to receive(:save).and_return(false)
        end

        it 'does not log any audit event' do
          expect { execute }.not_to change { AuditEventReader.count }
        end
      end
    end

    it_behaves_like 'does not create audit event when not licensed'
  end
end
