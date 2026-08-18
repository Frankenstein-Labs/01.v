# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllers::RevokeTokenService, :aggregate_failures, feature_category: :continuous_integration do
  include AdminModeHelper

  let_it_be(:runner_controller) { create(:ci_runner_controller) }
  let_it_be(:admin_user) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }

  let(:runner_controller_token) { create(:ci_runner_controller_token, runner_controller: runner_controller) }

  describe '#execute' do
    subject(:execute) { described_class.new(token: runner_controller_token, current_user: current_user).execute }

    context 'when the user is an admin' do
      let(:current_user) { admin_user }

      before do
        enable_admin_mode!(current_user)
      end

      it 'successfully revokes the token' do
        execute

        expect(runner_controller_token.reload.revoked?).to be true
      end

      it 'returns a success response' do
        response = execute

        expect(response).to be_success
      end

      it 'creates an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'runner_controller_token_revoked',
            author: admin_user,
            scope: an_instance_of(::Gitlab::Audit::InstanceScope),
            target: runner_controller_token,
            message: 'Revoked runner controller token'
          )
        )

        execute
      end

      context 'when it fails' do
        before do
          allow(runner_controller_token).to receive(:revoke!).and_return(false)
          allow(runner_controller_token).to receive_message_chain(:errors, :full_messages, :to_sentence)
            .and_return('Some error')
        end

        it 'returns an error response' do
          response = execute

          expect(response).to be_error
          expect(response.message).to eq('Some error')
        end

        it 'does not create an audit event for token revocation' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(
            hash_including(name: 'runner_controller_token_revoked')
          )

          execute
        end
      end
    end

    context 'when the user is not an admin' do
      let(:current_user) { non_admin_user }

      it 'returns an error response indicating insufficient permissions' do
        response = execute

        expect(response).to be_error
        expect(response.reason).to eq(:forbidden)
        expect(response.message).to eq('Administrator permission is required to revoke this token')
      end

      it 'does not revoke the token' do
        execute

        expect(runner_controller_token.reload.active?).to be true
      end

      it 'does not create an audit event for token revocation' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(
          hash_including(name: 'runner_controller_token_revoked')
        )

        execute
      end
    end
  end
end
