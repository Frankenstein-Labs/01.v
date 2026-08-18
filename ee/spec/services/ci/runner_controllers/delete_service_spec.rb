# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllers::DeleteService, :aggregate_failures, feature_category: :continuous_integration do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }

  describe '#execute' do
    let!(:runner_controller) { create(:ci_runner_controller) }

    subject(:execute) do
      described_class.new(
        runner_controller: runner_controller,
        current_user: current_user
      ).execute
    end

    context 'when user is admin' do
      let(:current_user) { admin }

      before do
        enable_admin_mode!(current_user)
      end

      it 'deletes the runner controller' do
        expect { execute }.to change { Ci::RunnerController.count }.by(-1)

        expect(execute).to be_success
      end

      it 'creates an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'runner_controller_deleted',
            author: admin,
            scope: an_instance_of(::Gitlab::Audit::InstanceScope),
            target: runner_controller,
            message: 'Deleted runner controller'
          )
        )

        execute
      end

      context 'when deletion fails' do
        before do
          allow(runner_controller).to receive(:destroy).and_return(false)
          allow(runner_controller).to receive_message_chain(:errors, :full_messages, :to_sentence)
            .and_return('Deletion failed')
        end

        it 'returns an error response' do
          expect { execute }.not_to change { Ci::RunnerController.count }

          expect(execute).to be_error
          expect(execute.message).to eq('Deletion failed')
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
        expect { execute }.not_to change { Ci::RunnerController.count }

        expect(execute).to be_error
        expect(execute.reason).to eq(:forbidden)
        expect(execute.message).to eq('Administrator permission is required to delete a runner controller')
      end

      it 'does not create an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end
  end
end
