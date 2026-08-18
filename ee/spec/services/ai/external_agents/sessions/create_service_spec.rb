# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ExternalAgents::Sessions::CreateService, feature_category: :software_composition_analysis do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:identity) do
    create(:ai_agent_identity, user: user, project: project,
      agent_type: 'claude-code', machine_fingerprint: 'a' * 64)
  end

  let(:params) do
    {
      agent_type: 'claude-code',
      agent_identity_id: identity.id,
      sync_type: 'hook'
    }
  end

  subject(:service) { described_class.new(project: project, current_user: user, params: params) }

  before do
    allow(user).to receive(:can?).with(:create_ai_agent_session, project).and_return(true)
  end

  describe '#execute' do
    context 'when authorized' do
      it 'creates a new session' do
        expect { service.execute }.to change { Ai::DuoWorkflows::Workflow.external.count }.by(1)
      end

      it 'returns success with the session' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:session]).to be_a(Ai::DuoWorkflows::Workflow)
        expect(result.payload[:session].agent_type).to eq('claude-code')
        expect(result.payload[:session].sync_type).to eq('hook')
        expect(result.payload[:session].environment).to eq('external')
      end

      it 'transitions the session to running' do
        result = service.execute

        expect(result.payload[:session].status_name).to eq(:running)
      end

      context 'with an idempotency key' do
        let(:params) { super().merge(idempotency_key: 'test-uuid-123') }

        it 'is idempotent -- returns existing session on repeat call' do
          first_result = service.execute
          second_result = service.execute

          expect(second_result).to be_success
          expect(second_result.payload[:session].id).to eq(first_result.payload[:session].id)
          expect(Ai::DuoWorkflows::Workflow.external.count).to eq(1)
        end
      end

      context 'with a goal' do
        let(:params) { super().merge(goal: 'Implement the login feature') }

        it 'sets the goal on the session' do
          result = service.execute

          expect(result.payload[:session].goal).to eq('Implement the login feature')
        end
      end

      context 'with a started_at timestamp' do
        let(:started_at) { 1.hour.ago }
        let(:params) { super().merge(started_at: started_at) }

        it 'sets the created_at to started_at' do
          result = service.execute

          expect(result.payload[:session].created_at).to be_within(1.second).of(started_at)
        end
      end

      context 'when started_at is more than 30 days in the past' do
        let(:params) { super().merge(started_at: 31.days.ago) }

        it 'returns an error' do
          result = service.execute
          expect(result).to be_error
          expect(result.message).to include('30 days')
        end
      end

      context 'with a future started_at timestamp' do
        let(:params) { super().merge(started_at: 1.hour.from_now) }

        it 'returns an error' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to include('future')
        end

        it 'does not create a session' do
          expect { service.execute }.not_to change { Ai::DuoWorkflows::Workflow.external.count }
        end
      end

      context 'when agent_identity_id belongs to a different agent_type' do
        let_it_be(:opencode_identity) do
          create(:ai_agent_identity, user: user, project: project,
            agent_type: 'opencode', machine_fingerprint: 'b' * 64)
        end

        let(:params) { super().merge(agent_type: 'claude-code', agent_identity_id: opencode_identity.id) }

        it 'returns not found error' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Agent identity not found')
        end
      end

      context 'when agent_identity is revoked' do
        let_it_be(:revoked_identity) do
          create(:ai_agent_identity, user: user, project: project,
            agent_type: 'claude-code', machine_fingerprint: 'c' * 64,
            revoked_at: Time.current)
        end

        let(:params) { super().merge(agent_identity_id: revoked_identity.id) }

        it 'returns not found error' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Agent identity not found')
        end
      end
    end

    context 'when not authorized' do
      before do
        allow(user).to receive(:can?).with(:create_ai_agent_session, project).and_return(false)
      end

      it 'returns an error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Unauthorized')
      end

      it 'does not create a session' do
        expect { service.execute }.not_to change { Ai::DuoWorkflows::Workflow.external.count }
      end
    end
  end
end
