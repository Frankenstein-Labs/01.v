# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllers::Scopes::RemoveInstanceService, :aggregate_failures, feature_category: :continuous_integration do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }
  let_it_be_with_refind(:runner_controller) { create(:ci_runner_controller) }

  describe '#execute' do
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

      context 'when instance-level scoping exists' do
        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: runner_controller)
        end

        it 'removes the instance-level scoping' do
          expect { execute }.to change { Ci::RunnerControllerInstanceLevelScoping.count }.by(-1)

          expect(execute).to be_success
        end

        it 'creates an audit event' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'runner_controller_instance_scope_removed',
              author: admin,
              scope: an_instance_of(::Gitlab::Audit::InstanceScope),
              message: 'Removed instance-level scope from runner controller'
            )
          )

          execute
        end
      end

      context 'when scoping fails to destroy' do
        let!(:scoping) { create(:ci_runner_controller_instance_level_scoping, runner_controller: runner_controller) }

        before do
          allow(runner_controller).to receive(:instance_level_scoping).and_return(scoping)
          allow(scoping).to receive(:destroy).and_return(false)
          allow(scoping).to receive_message_chain(:errors, :full_messages).and_return(['Destroy error'])
        end

        it 'returns an error response' do
          expect(execute).to be_error
          expect(execute.message).to eq('Destroy error')
        end

        it 'does not create an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          execute
        end
      end

      context 'when no instance-level scoping exists' do
        it 'returns success - idempotent' do
          expect { execute }.not_to change { Ci::RunnerControllerInstanceLevelScoping.count }

          expect(execute).to be_success
        end

        it 'does not create an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          execute
        end
      end
    end

    context 'when user is not admin' do
      let(:current_user) { non_admin_user }

      before do
        create(:ci_runner_controller_instance_level_scoping, runner_controller: runner_controller)
      end

      it 'returns forbidden error' do
        expect { execute }.not_to change { Ci::RunnerControllerInstanceLevelScoping.count }

        expect(execute).to be_error
        expect(execute.reason).to eq(:forbidden)
        expect(execute.message).to eq('Administrator permission is required to remove instance-level scope')
      end

      it 'does not create an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end
  end
end
