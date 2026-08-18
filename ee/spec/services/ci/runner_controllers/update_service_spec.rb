# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllers::UpdateService, :aggregate_failures, feature_category: :continuous_integration do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }
  let_it_be_with_refind(:runner_controller) { create(:ci_runner_controller, state: 'disabled') }

  let(:params) { { state: 'enabled' } }

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

      it 'updates the runner controller' do
        expect { execute }.to change { runner_controller.reload.state }.from('disabled').to('enabled')

        expect(execute).to be_success
        expect(execute.payload).to eq(runner_controller)
      end

      context 'when state is changed' do
        it 'creates an audit event with state change details' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'runner_controller_updated',
              author: admin,
              scope: an_instance_of(::Gitlab::Audit::InstanceScope),
              target: runner_controller,
              message: 'Updated runner controller state from disabled to enabled',
              additional_details: { state_changed: { from: 'disabled', to: 'enabled' } }
            )
          )

          execute
        end
      end

      context 'when state is not changed' do
        let(:params) { { description: 'New description' } }

        it 'creates an audit event without state change details' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'runner_controller_updated',
              author: admin,
              scope: an_instance_of(::Gitlab::Audit::InstanceScope),
              target: runner_controller,
              message: 'Updated runner controller'
            )
          )

          execute
        end

        it 'does not include additional_details when empty' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_not_including(:additional_details)
          )

          execute
        end
      end

      context 'when update fails' do
        let(:params) { { description: 'a' * 2000 } }

        it 'returns an error response' do
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
        expect { execute }.not_to change { runner_controller.reload.state }

        expect(execute).to be_error
        expect(execute.reason).to eq(:forbidden)
        expect(execute.message).to eq('Administrator permission is required to update a runner controller')
      end

      it 'does not create an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end
  end
end
