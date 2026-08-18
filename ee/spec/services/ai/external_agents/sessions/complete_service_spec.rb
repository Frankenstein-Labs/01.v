# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ExternalAgents::Sessions::CompleteService, feature_category: :software_composition_analysis do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:other_user) { create(:user, developer_of: project) }
  let_it_be(:identity) do
    create(:ai_agent_identity, user: user, project: project,
      agent_type: 'claude-code', machine_fingerprint: 'a' * 64)
  end

  let_it_be_with_reload(:session) do
    create(:duo_workflows_workflow, :running, user: user, project: project,
      environment: :external, agent_type: 'claude-code', sync_type: :hook,
      agent_identity_id: identity.id)
  end

  let(:params) { { status: 'completed' } }

  subject(:service) do
    described_class.new(project: project, current_user: user, session: session, params: params)
  end

  before do
    allow(user).to receive(:can?).with(:update_ai_agent_session, project).and_return(true)
  end

  describe '#execute' do
    context 'when authorized and owner' do
      it 'transitions the session to finished' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:session].status_name).to eq(:finished)
      end

      context 'when status is failed' do
        let(:params) { { status: 'failed' } }

        it 'transitions the session to failed' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:session].status_name).to eq(:failed)
        end
      end

      context 'with jsonl_sha256' do
        let(:params) { { status: 'completed', jsonl_sha256: 'a' * 64 } }

        it 'sets the jsonl_sha256 on the session' do
          result = service.execute

          expect(result.payload[:session].jsonl_sha256).to eq('a' * 64)
        end

        context 'when jsonl_sha256 matches stored value and session is already terminal' do
          before do
            session.update!(jsonl_sha256: 'a' * 64)
            session.finish!
          end

          let(:params) { { status: 'completed', jsonl_sha256: 'a' * 64 } }

          it 'returns existing record without transitioning' do
            result = service.execute
            expect(result.payload[:session].status_name).to eq(:finished)
          end
        end
      end

      context 'when not the session owner' do
        subject(:service) do
          described_class.new(project: project, current_user: other_user, session: session, params: params)
        end

        before do
          allow(other_user).to receive(:can?).with(:update_ai_agent_session, project).and_return(true)
        end

        it 'returns a forbidden error' do
          result = service.execute

          expect(result).to be_error
          expect(result.reason).to eq(:forbidden)
        end

        it 'does not change the session status' do
          expect { service.execute }.not_to change { session.reload.status }
        end
      end
    end

    context 'when not authorized' do
      before do
        allow(user).to receive(:can?).with(:update_ai_agent_session, project).and_return(false)
      end

      it 'returns an unauthorized error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Unauthorized')
      end
    end
  end
end
