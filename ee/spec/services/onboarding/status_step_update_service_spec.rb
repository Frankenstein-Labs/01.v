# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::StatusStepUpdateService, feature_category: :onboarding do
  describe '#execute' do
    let_it_be(:original_step_url) { '_string_' }
    let_it_be_with_reload(:user) do
      create(:user, onboarding_in_progress: true, onboarding_status: { 'step_url' => original_step_url })
    end

    let(:step_url) { 'foobar' }

    subject(:execute) { described_class.new(user, step_url).execute }

    context 'when user qualifies as onboarding' do
      before do
        stub_saas_features(onboarding: true)
      end

      context 'when update is successful' do
        it 'updates onboarding_status_step_url' do
          expect { execute }.to change { user.onboarding_status_step_url }.to(step_url)
          expect(execute).to be_a(ServiceResponse)
          expect(execute).to be_success
          expect(execute[:step_url]).to eq(step_url)
        end
      end

      context 'when update is not successful' do
        let(:step_url) { nil }

        it 'does not update the onboarding_status_step_url' do
          expect { execute }.not_to change { user.onboarding_status_step_url }
          expect(execute).to be_a(ServiceResponse)
          expect(execute).to be_error
          expect(execute[:step_url]).to eq(original_step_url)
        end

        it 'tracks the error' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(::Onboarding::StepUrlError),
            onboarding_status: user.onboarding_status.merge(step_url: step_url).to_json,
            user_id: user.id
          )

          execute
        end
      end
    end

    context 'when user does not qualify as onboarding' do
      before do
        stub_saas_features(onboarding: false)
      end

      it 'does not update onboarding_in_progress' do
        expect { execute }.not_to change { user.onboarding_status_step_url }
        expect(execute).to be_a(ServiceResponse)
        expect(execute).to be_error
        expect(execute[:step_url]).to eq(original_step_url)
      end
    end
  end
end
