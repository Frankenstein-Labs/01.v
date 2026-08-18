# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllers::Scopes::RemoveRunnerService, :aggregate_failures, feature_category: :continuous_integration do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }
  let_it_be_with_refind(:runner_controller) { create(:ci_runner_controller) }
  let_it_be(:instance_runner) { create(:ci_runner, :instance) }

  describe '#execute' do
    subject(:execute) do
      described_class.new(
        runner_controller: runner_controller,
        runner: instance_runner,
        current_user: current_user
      ).execute
    end

    context 'when user is admin' do
      let(:current_user) { admin }

      before do
        enable_admin_mode!(current_user)
      end

      context 'when runner-level scoping exists' do
        before do
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: runner_controller,
            runner: instance_runner)
        end

        it 'removes the runner-level scoping' do
          expect { execute }.to change { Ci::RunnerControllerRunnerLevelScoping.count }.by(-1)

          expect(execute).to be_success
        end

        it 'creates an audit event' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'runner_controller_runner_scope_removed',
              author: admin,
              scope: an_instance_of(::Gitlab::Audit::InstanceScope),
              message: "Removed runner scope for runner ##{instance_runner.id} from runner controller"
            )
          )

          execute
        end
      end

      context 'when scoping fails to destroy' do
        let!(:scoping) do
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: runner_controller,
            runner: instance_runner)
        end

        before do
          scope_relation = instance_double(ActiveRecord::Relation)
          allow(runner_controller.runner_level_scopings).to receive(:for_runner)
            .with(instance_runner.id)
            .and_return(scope_relation)
          allow(scope_relation).to receive(:first).and_return(scoping)
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

      context 'when no runner-level scoping exists' do
        it 'returns success - idempotent' do
          expect { execute }.not_to change { Ci::RunnerControllerRunnerLevelScoping.count }

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
        create(:ci_runner_controller_runner_level_scoping,
          runner_controller: runner_controller,
          runner: instance_runner)
      end

      it 'returns forbidden error' do
        expect { execute }.not_to change { Ci::RunnerControllerRunnerLevelScoping.count }

        expect(execute).to be_error
        expect(execute.reason).to eq(:forbidden)
        expect(execute.message).to eq('Administrator permission is required to remove runner scope')
      end

      it 'does not create an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end
  end
end
