# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ExternalAgents::Identities::RegisterService, feature_category: :software_composition_analysis do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:agent_type) { 'claude-code' }
  let(:machine_fingerprint) { 'a' * 64 }
  let(:params) { { agent_type: agent_type, machine_fingerprint: machine_fingerprint } }

  subject(:service) { described_class.new(project: project, current_user: user, params: params) }

  describe '#execute' do
    context 'when the user is authorized' do
      before do
        allow(user).to receive(:can?).with(:create_ai_agent_identity, project).and_return(true)
      end

      it 'creates a new identity and returns success' do
        expect { service.execute }.to change { Ai::ExternalAgents::AgentIdentity.count }.by(1)

        result = service.execute
        expect(result).to be_success
        expect(result.payload[:identity]).to be_a(Ai::ExternalAgents::AgentIdentity)
        expect(result.payload[:identity].agent_type).to eq(agent_type)
        expect(result.payload[:identity].machine_fingerprint).to eq(machine_fingerprint)
      end

      it 'is idempotent -- returns existing identity on repeat call' do
        first_result = service.execute
        second_result = service.execute

        expect(second_result).to be_success
        expect(second_result.payload[:identity].id).to eq(first_result.payload[:identity].id)
        expect(Ai::ExternalAgents::AgentIdentity.count).to eq(1)
      end

      context 'when the identity has been revoked' do
        before do
          create(:ai_agent_identity, user: user, project: project,
            agent_type: agent_type, machine_fingerprint: machine_fingerprint,
            revoked_at: Time.current)
        end

        it 'returns a forbidden error' do
          result = service.execute

          expect(result).to be_error
          expect(result.reason).to eq(:forbidden)
          expect(result.message).to eq('Agent identity has been revoked')
        end
      end

      context 'when params are invalid' do
        let(:agent_type) { 'unknown-agent' }

        it 'returns an error with validation messages' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Failed to register identity')
        end
      end
    end

    context 'when the user is not authorized' do
      before do
        allow(user).to receive(:can?).with(:create_ai_agent_identity, project).and_return(false)
      end

      it 'returns an unauthorized error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Unauthorized')
      end

      it 'does not create an identity' do
        expect { service.execute }.not_to change { Ai::ExternalAgents::AgentIdentity.count }
      end
    end
  end
end
