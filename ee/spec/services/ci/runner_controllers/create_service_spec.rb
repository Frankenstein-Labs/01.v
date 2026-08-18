# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerControllers::CreateService, :aggregate_failures, feature_category: :continuous_integration do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:non_admin_user) { create(:user) }

  let(:params) { { description: 'Test controller', state: 'enabled' } }

  describe '#execute' do
    subject(:execute) { described_class.new(current_user: current_user, params: params).execute }

    context 'when user is admin' do
      let(:current_user) { admin }

      before do
        enable_admin_mode!(current_user)
      end

      it 'creates a runner controller' do
        expect { execute }.to change { Ci::RunnerController.count }.by(1)

        expect(execute).to be_success
        expect(execute.payload).to be_a(Ci::RunnerController)
        expect(execute.payload.description).to eq('Test controller')
        expect(execute.payload.state).to eq('enabled')
      end

      it 'creates an audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'runner_controller_created',
            author: admin,
            scope: an_instance_of(::Gitlab::Audit::InstanceScope),
            message: a_string_matching(/Created runner controller with state enabled/),
            additional_details: { state: 'enabled' }
          )
        )

        execute
      end

      context 'with default state' do
        let(:params) { { description: 'Test controller' } }

        it 'creates a runner controller with disabled state' do
          expect(execute).to be_success
          expect(execute.payload.state).to eq('disabled')
        end

        it 'creates an audit event with disabled state' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              message: a_string_matching(/Created runner controller with state disabled/),
              additional_details: { state: 'disabled' }
            )
          )

          execute
        end
      end

      context 'when controller fails to save' do
        let(:params) { { description: 'a' * 2000 } }

        it 'returns an error response' do
          expect { execute }.not_to change { Ci::RunnerController.count }

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
        expect { execute }.not_to change { Ci::RunnerController.count }

        expect(execute).to be_error
        expect(execute.reason).to eq(:forbidden)
        expect(execute.message).to eq('Administrator permission is required to create a runner controller')
      end

      it 'does not create an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end
  end
end
