# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ExternalStatusChecks::DestroyService, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project) }

  let(:current_user) { project.first_owner }

  let_it_be_with_refind(:external_status_check) { create(:external_status_check, name: 'QA', project: project) }

  subject(:execute) do
    described_class.new(container: project, current_user: current_user, params: { id: external_status_check.id })
      .execute
  end

  context 'when current user is project owner' do
    it 'deletes an external status check' do
      expect { execute }.to change { MergeRequests::ExternalStatusCheck.count }.by(-1)
    end

    it 'is successful' do
      expect(execute.success?).to be true
    end
  end

  context 'when current user is not a project owner' do
    let(:current_user) { create(:user) }

    it 'does not delete an external status check' do
      expect { execute }.not_to change { MergeRequests::ExternalStatusCheck.count }
    end

    it 'is unsuccessful' do
      expect(execute.error?).to be true
    end

    it 'returns an unauthorized status' do
      expect(execute.http_status).to eq(:unauthorized)
    end

    it 'contains an appropriate message and error' do
      expect(execute.message).to eq('Failed to destroy external status check')
      expect(execute.payload[:errors]).to contain_exactly('Not allowed')
    end
  end

  describe 'audit events' do
    context 'when licensed' do
      before do
        stub_licensed_features(audit_events: true)
      end

      context 'when external status check destroy operation succeeds', :request_store do
        it 'logs an audit event' do
          expect { execute }.to change { AuditEventReader.count }.by(1)
          expect(AuditEventReader.last.details).to include({
            target_type: 'MergeRequests::ExternalStatusCheck',
            custom_message: 'Removed QA status check'
          })
        end
      end

      context 'when external status check destroy operation fails' do
        let_it_be_with_refind(:failing_external_status_check) do
          create(:external_status_check, name: 'Failing Check', project: project)
        end

        subject(:execute_failing) do
          described_class.new(
            container: project,
            current_user: current_user,
            params: { id: failing_external_status_check.id }
          ).execute
        end

        before do
          allow(::MergeRequests::ExternalStatusCheck).to receive(:destroy).and_return(false)
        end

        it 'does not log any audit event' do
          expect { execute_failing }.not_to change { AuditEventReader.count }
        end
      end
    end

    it_behaves_like 'does not create audit event when not licensed'
  end
end
