# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::TrialDurationService, feature_category: :acquisition do
  include SubscriptionPortalHelpers

  describe '#execute', :use_clean_rails_memory_store_caching do
    let(:subscriptions_trials_enabled) { true }
    let(:free_duration) { 1 }
    let(:premium_duration) { 2 }
    let(:premium_next_duration) { 3 }
    let(:duo_enterprise_duration) { 4 }
    let(:duo_enterprise_next_duration) { 5 }
    let(:corrupted_trial_type) { '_corrupted_trial_type_' }
    let(:corrupted_duration) { 6 }
    let(:corrupted_next_duration) { 7 }
    let(:default_free_duration) { 30 }
    let(:default_duo_enterprise_duration) { 60 }

    let(:trial_types) do
      {
        GitlabSubscriptions::Trials::FREE_TRIAL_TYPE => { duration_days: free_duration },
        GitlabSubscriptions::Trials::FREE_TRIAL_TYPE_V2 => { duration_days: free_duration },
        GitlabSubscriptions::Trials::PREMIUM_TRIAL_TYPE => {
          duration_days: premium_duration,
          next_duration_days: premium_next_duration,
          next_active_time: 1.day.ago.to_s
        },
        GitlabSubscriptions::Trials::PREMIUM_TRIAL_TYPE_V2 => {
          duration_days: premium_duration,
          next_duration_days: premium_next_duration,
          next_active_time: 1.day.ago.to_s
        },
        GitlabSubscriptions::Trials::DUO_ENTERPRISE_TRIAL_TYPE => {
          duration_days: duo_enterprise_duration,
          next_duration_days: duo_enterprise_next_duration,
          next_active_time: 1.day.from_now.to_s
        },
        corrupted_trial_type => {
          duration_days: corrupted_duration,
          next_duration_days: corrupted_next_duration,
          next_active_time: {}
        }
      }
    end

    let(:response) { { success: true, data: { trial_types: trial_types } } }

    subject(:service) { described_class.new }

    before do
      stub_saas_features(subscriptions_trials: subscriptions_trials_enabled)
      stub_subscription_trial_types(trial_types: trial_types)
    end

    it 'makes a request, caches it, and returns correct duration' do
      expect(Gitlab::SubscriptionPortal::Client).to receive(:namespace_trial_types).once.and_return(response)
      expect(service.execute).to eq(free_duration)
    end

    it 'uses cache on subsequent calls' do
      service.execute

      expect(Gitlab::SubscriptionPortal::Client).not_to receive(:namespace_trial_types)
      expect(service.execute).to eq(free_duration)
    end

    it 'uses Rails cache with correct key and expiry' do
      expect(Rails.cache).to receive(:fetch)
        .with('gitlab_subscriptions_trial_duration_service', expires_in: 1.hour)
        .and_call_original

      service.execute
    end

    context 'when subscriptions_trials feature is not available' do
      let(:subscriptions_trials_enabled) { false }

      it 'returns nil' do
        expect(service.execute).to be_nil
      end
    end

    context 'when cache fails' do
      before do
        allow(Rails.cache).to receive(:fetch)
          .with('gitlab_subscriptions_trial_duration_service', expires_in: 1.hour)
          .and_return(nil)
      end

      it 'falls back to empty hash and returns default duration' do
        expect(service.execute).to eq(default_free_duration)
      end
    end

    context 'when trial type is specified' do
      before do
        service.execute # first execution to populate cache
      end

      subject(:service) { described_class.new(trial_type) }

      context 'with next_active_time' do
        context 'when next active time is in the past' do
          let(:trial_type) { GitlabSubscriptions::Trials::PREMIUM_TRIAL_TYPE }

          it { expect(service.execute).to eq(premium_next_duration) }
        end

        context 'when next active time is in the future' do
          let(:trial_type) { GitlabSubscriptions::Trials::DUO_ENTERPRISE_TRIAL_TYPE }

          it { expect(service.execute).to eq(duo_enterprise_duration) }
        end

        context 'when next active time is corrupted' do
          let(:trial_type) { corrupted_trial_type }

          it { expect(service.execute).to eq(corrupted_duration) }
        end
      end

      context 'when trial type is missing from response' do
        let(:trial_type) { '__trial_type__' }

        it { expect(service.execute).to be_nil }
      end
    end

    context 'with an unsuccessful CustomersDot query' do
      before do
        stub_subscription_trial_types(success: false)
      end

      it { expect(service.execute).to eq(default_free_duration) }

      context 'when trial type is specified' do
        let(:trial_type) { GitlabSubscriptions::Trials::DUO_ENTERPRISE_TRIAL_TYPE }

        subject(:service) { described_class.new(trial_type) }

        it { expect(service.execute).to eq(default_duo_enterprise_duration) }

        context 'when trial type is missing from defaults' do
          let(:trial_type) { '__trial_type__' }

          it { expect(service.execute).to be_nil }
        end
      end
    end
  end
end
