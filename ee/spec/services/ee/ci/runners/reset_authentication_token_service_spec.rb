# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::ResetAuthenticationTokenService, '#execute', :aggregate_failures, feature_category: :fleet_visibility do
  before_all do
    freeze_time # Freeze time before `let_it_be` runs, so that time is immediately frozen before computing deadlines
  end

  after :all do
    unfreeze_time
  end

  let_it_be_with_refind(:runner_without_token_rotation_deadline) { create(:ci_runner) }
  let_it_be_with_refind(:runner_with_future_rotation_deadline) { create(:ci_runner, :with_future_rotation_deadline) }
  let_it_be(:runner_with_past_rotation_deadline) { create(:ci_runner, :with_past_rotation_deadline) }
  let_it_be(:runner_at_token_rotation_deadline) { create(:ci_runner, token_rotation_deadline: Time.current) }

  let(:service) { described_class.new(runner: runner, current_user: current_user, source: source) }

  subject(:execute) { service.execute }

  shared_examples 'rotation deadline behavior' do
    context 'when token_rotation_deadline is nil' do
      let(:runner) { runner_without_token_rotation_deadline }

      it 'does reset authentication token and returns success' do
        expect { execute }.to change { runner.reload.token }
        expect(execute).to be_success
      end
    end

    context 'when runner has token_rotation_deadline in the future' do
      let(:runner) { runner_with_future_rotation_deadline }

      it 'resets token and clears token_rotation_deadline' do
        expect { execute }.to change { runner.reload.token }
        expect(execute).to be_success
        expect(runner.reload.token_rotation_deadline).to be_nil
      end
    end

    context 'when rotation deadline has passed' do
      let(:runner) { runner_with_past_rotation_deadline }

      it 'rejects rotation with forbidden error' do
        expect(execute).to be_error
        expect(execute.reason).to eq(:forbidden)
        expect(execute.message).to include('Token rotation deadline has passed')
      end

      it 'does not change the token' do
        expect { execute }.not_to change { runner.reload.token }
      end
    end

    context 'when rotation deadline is exactly now' do
      let(:runner) { runner_at_token_rotation_deadline }

      it 'rejects rotation with forbidden error' do
        expect(execute).to be_error
        expect(execute.reason).to eq(:forbidden)
        expect(execute.message).to include('Token rotation deadline has passed')
      end
    end
  end

  context 'without source' do
    let(:source) { nil }

    context 'with admin', :enable_admin_mode do
      let_it_be(:current_user) { build(:admin) }

      it_behaves_like 'rotation deadline behavior'
    end
  end

  context 'with source' do
    let(:current_user) { nil }

    context 'with permitted source' do
      let(:source) { :runner_api }

      it_behaves_like 'rotation deadline behavior'
    end
  end
end
