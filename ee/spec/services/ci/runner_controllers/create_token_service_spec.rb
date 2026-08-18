# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllers::CreateTokenService, :aggregate_failures, feature_category: :continuous_integration do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }
  let_it_be(:runner_controller) { create(:ci_runner_controller) }

  let(:params) { { description: 'Test token' } }

  describe '#execute' do
    subject(:execute) do
      described_class.new(
        runner_controller: runner_controller,
        current_user: current_user,
        params: params
      ).execute
    end

    context 'when user is admin' do
      let(:current_user) { admin }

      before do
        enable_admin_mode!(current_user)
      end

      it 'creates a runner controller token' do
        expect { execute }.to change { Ci::RunnerControllerToken.count }.by(1)

        expect(execute).to be_success
        expect(execute.payload).to be_a(Ci::RunnerControllerToken)
        expect(execute.payload.description).to eq('Test token')
        expect(execute.payload.runner_controller).to eq(runner_controller)
      end

      it 'creates an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'runner_controller_token_created',
            author: admin,
            scope: an_instance_of(::Gitlab::Audit::InstanceScope),
            message: 'Created runner controller token'
          )
        )

        execute
      end

      context 'when token fails to save' do
        let(:params) { { description: 'a' * 2000 } }

        it 'returns an error response' do
          expect { execute }.not_to change { Ci::RunnerControllerToken.count }

          expect(execute).to be_error
          expect(execute.message).to include('Description')
        end

        it 'does not create an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          execute
        end
      end
    end

    context 'when user is not admin' do
      let(:current_user) { non_admin_user }

      it 'returns forbidden error' do
        expect { execute }.not_to change { Ci::RunnerControllerToken.count }

        expect(execute).to be_error
        expect(execute.reason).to eq(:forbidden)
        expect(execute.message).to eq('Administrator permission is required to create a runner controller token')
      end

      it 'does not create an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end
  end
end
