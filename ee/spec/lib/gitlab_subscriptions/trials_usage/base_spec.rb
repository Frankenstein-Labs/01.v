# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::TrialsUsage::Base, feature_category: :consumables_cost_management do
  let_it_be(:group) { create(:group) }

  let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }
  let(:subscription_target) { :namespace }
  let(:namespace) { group }

  subject(:trial_usage) do
    described_class.new(
      subscription_target: subscription_target,
      subscription_usage_client: subscription_usage_client,
      namespace: namespace
    )
  end

  describe '#active_trial' do
    context 'when trial usage data is available' do
      let(:trial_usage_response) do
        {
          success: true,
          trialUsage: {
            activeTrial: {
              startDate: '2026-02-01',
              endDate: '2026-03-03'
            }
          }
        }
      end

      before do
        allow(subscription_usage_client).to receive(:get_trial_usage).and_return(trial_usage_response)
      end

      it 'returns active trial information' do
        active_trial = trial_usage.active_trial

        expect(active_trial).to be_a(GitlabSubscriptions::TrialsUsage::Base::ActiveTrial)
        expect(active_trial.start_date).to eq('2026-02-01')
        expect(active_trial.end_date).to eq('2026-03-03')
      end
    end

    context 'when API call fails' do
      let(:trial_usage_response) do
        {
          success: false
        }
      end

      before do
        allow(subscription_usage_client).to receive(:get_trial_usage).and_return(trial_usage_response)
      end

      it 'returns nil' do
        expect(trial_usage.active_trial).to be_nil
      end
    end

    context 'when trialUsage data is not present' do
      let(:trial_usage_response) do
        {
          success: true,
          trialUsage: nil
        }
      end

      before do
        allow(subscription_usage_client).to receive(:get_trial_usage).and_return(trial_usage_response)
      end

      it 'returns nil' do
        expect(trial_usage.active_trial).to be_nil
      end
    end
  end

  describe '#trial_users_usage' do
    context 'when trial usage data is available' do
      let(:trial_usage_response) do
        {
          success: true,
          trialUsage: {
            activeTrial: {
              startDate: '2026-02-01',
              endDate: '2026-03-03'
            },
            usersUsage: {
              creditsUsed: 45.8,
              totalUsersUsingCredits: 3
            }
          }
        }
      end

      before do
        allow(subscription_usage_client).to receive(:get_trial_usage).and_return(trial_usage_response)
      end

      it 'returns a TrialsUsage::UserUsage instance' do
        expect(trial_usage.trial_users_usage).to be_a(GitlabSubscriptions::TrialsUsage::UserUsage)
      end
    end

    context 'when API call fails' do
      let(:trial_usage_response) do
        {
          success: false
        }
      end

      before do
        allow(subscription_usage_client).to receive(:get_trial_usage).and_return(trial_usage_response)
      end

      it 'returns nil' do
        expect(trial_usage.trial_users_usage).to be_nil
      end
    end

    context 'when trialUsage data is not present' do
      let(:trial_usage_response) do
        {
          success: true,
          trialUsage: nil
        }
      end

      before do
        allow(subscription_usage_client).to receive(:get_trial_usage).and_return(trial_usage_response)
      end

      it 'returns nil' do
        expect(trial_usage.trial_users_usage).to be_nil
      end
    end
  end
end
