# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllers::Scopes::AddRunnerService, :aggregate_failures, feature_category: :continuous_integration do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }
  let_it_be_with_refind(:runner_controller) { create(:ci_runner_controller) }
  let_it_be(:instance_runner) { create(:ci_runner, :instance) }
  let_it_be(:project) { create(:project) }
  let_it_be(:project_runner) { create(:ci_runner, :project, projects: [project]) }

  describe '#execute' do
    subject(:execute) do
      described_class.new(
        runner_controller: runner_controller,
        runner: runner,
        current_user: current_user
      ).execute
    end

    let(:runner) { instance_runner }

    context 'when user is admin' do
      let(:current_user) { admin }

      before do
        enable_admin_mode!(current_user)
      end

      it 'creates a runner-level scoping' do
        expect { execute }.to change { Ci::RunnerControllerRunnerLevelScoping.count }.by(1)

        expect(execute).to be_success
        expect(execute.payload).to be_a(Ci::RunnerControllerRunnerLevelScoping)
        expect(execute.payload.runner_controller).to eq(runner_controller)
        expect(execute.payload.runner).to eq(instance_runner)
      end

      it 'creates an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'runner_controller_runner_scope_added',
            author: admin,
            scope: an_instance_of(::Gitlab::Audit::InstanceScope),
            message: "Added runner scope for runner ##{instance_runner.id} to runner controller"
          )
        )

        execute
      end

      context 'when runner is not instance-type' do
        let(:runner) { project_runner }

        it 'returns unprocessable_entity error' do
          expect { execute }.not_to change { Ci::RunnerControllerRunnerLevelScoping.count }

          expect(execute).to be_error
          expect(execute.reason).to eq(:unprocessable_entity)
          expect(execute.message).to eq('Only instance-type runners can be scoped')
        end

        it 'does not create an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          execute
        end
      end

      context 'when runner controller already has instance-level scope' do
        before do
          create(:ci_runner_controller_instance_level_scoping, runner_controller: runner_controller)
        end

        it 'returns conflict error' do
          expect { execute }.not_to change { Ci::RunnerControllerRunnerLevelScoping.count }

          expect(execute).to be_error
          expect(execute.reason).to eq(:conflict)
          expect(execute.message).to eq(
            'Runner controller already has instance-level scope. Remove it before adding runner scopes.'
          )
        end

        it 'does not create an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          execute
        end
      end

      context 'when runner scope already exists' do
        before do
          create(:ci_runner_controller_runner_level_scoping,
            runner_controller: runner_controller,
            runner: instance_runner)
        end

        it 'returns conflict error' do
          expect { execute }.not_to change { Ci::RunnerControllerRunnerLevelScoping.count }

          expect(execute).to be_error
          expect(execute.reason).to eq(:conflict)
          expect(execute.message).to eq('Runner scope already exists for this runner controller')
        end

        it 'does not create an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          execute
        end
      end

      context 'when scoping fails to save' do
        before do
          allow_next_instance_of(Ci::RunnerControllerRunnerLevelScoping) do |scoping|
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

      context 'when a race condition causes a unique constraint violation' do
        before do
          allow_next_instance_of(Ci::RunnerControllerRunnerLevelScoping) do |scoping|
            allow(scoping).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
          end
        end

        it 'returns conflict error' do
          expect(execute).to be_error
          expect(execute.reason).to eq(:conflict)
          expect(execute.message).to eq('Runner scope already exists for this runner controller')
        end
      end
    end

    context 'when user is not admin' do
      let(:current_user) { non_admin_user }

      it 'returns forbidden error' do
        expect { execute }.not_to change { Ci::RunnerControllerRunnerLevelScoping.count }

        expect(execute).to be_error
        expect(execute.reason).to eq(:forbidden)
        expect(execute.message).to eq('Administrator permission is required to add runner scope')
      end

      it 'does not create an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end
  end
end
