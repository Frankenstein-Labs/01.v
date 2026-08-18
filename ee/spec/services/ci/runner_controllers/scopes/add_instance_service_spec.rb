# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllers::Scopes::AddInstanceService, :aggregate_failures, feature_category: :continuous_integration do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }
  let_it_be_with_refind(:runner_controller) { create(:ci_runner_controller) }

  describe '#execute' do
    subject(:execute) { described_class.new(runner_controller: runner_controller, current_user: current_user).execute }

    context 'when user is admin' do
      let(:current_user) { admin }

      before do
        enable_admin_mode!(current_user)
      end

      it 'creates an instance-level scoping' do
        expect { execute }.to change { Ci::RunnerControllerInstanceLevelScoping.count }.by(1)

        expect(execute).to be_success
        expect(execute.payload).to be_a(Ci::RunnerControllerInstanceLevelScoping)
        expect(execute.payload.runner_controller).to eq(runner_controller)
      end

      it 'creates an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'runner_controller_instance_scope_added',
            author: admin,
            scope: an_instance_of(::Gitlab::Audit::InstanceScope),
            message: 'Added instance-level scope to runner controller'
          )
        )

        execute
      end

      context 'when instance-level scoping already exists' do
        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: runner_controller)
        end

        it 'returns conflict error' do
          expect { execute }.not_to change { Ci::RunnerControllerInstanceLevelScoping.count }

          expect(execute).to be_error
          expect(execute.reason).to eq(:conflict)
          expect(execute.message).to eq('Instance-level scope already exists for this runner controller')
        end

        it 'does not create an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          execute
        end
      end

      context 'when runner controller already has runner-level scopings' do
        let_it_be(:instance_runner) { create(:ci_runner, :instance) }

        before do
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: runner_controller,
            runner: instance_runner)
        end

        it 'returns conflict error' do
          expect { execute }.not_to change { Ci::RunnerControllerInstanceLevelScoping.count }

          expect(execute).to be_error
          expect(execute.reason).to eq(:conflict)
          expect(execute.message).to eq(
            'Runner controller already has runner-level scopes. Remove them before adding instance-level scope.'
          )
        end
      end

      context 'when scoping fails to save' do
        before do
          allow_next_instance_of(Ci::RunnerControllerInstanceLevelScoping) do |scoping|
            allow(scoping).to receive(:save).and_return(false)
            allow(scoping).to receive_message_chain(:errors, :full_messages).and_return(['Some error'])
          end
        end

        it 'returns an error response' do
          expect(execute).to be_error
          expect(execute.message).to eq('Some error')
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
        expect { execute }.not_to change { Ci::RunnerControllerInstanceLevelScoping.count }

        expect(execute).to be_error
        expect(execute.reason).to eq(:forbidden)
        expect(execute.message).to eq('Administrator permission is required to add instance-level scope')
      end

      it 'does not create an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end
  end
end
