# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::SelfManaged::StatusWidgetPresenter, feature_category: :acquisition do
  describe '#attributes' do
    let(:trial_duration) { 30 }
    let(:license) { build(:license, :ultimate_trial) }
    let(:user) { build(:user) }

    subject(:attributes) { described_class.new(license, user: user).attributes }

    it 'returns correct attributes' do
      trial_widget_data_attrs = {
        trial_type: 'self_managed_ultimate',
        trial_days_used: 1,
        days_remaining: trial_duration,
        percentage_complete: 3.33,
        trial_discover_page_path: admin_discover_premium_path,
        purchase_now_url: promo_pricing_url(query: { deployment: 'self-managed' }),
        feature_id: described_class::EXPIRED_TRIAL_WIDGET
      }

      expect(attributes).to eq(trial_widget_data_attrs: trial_widget_data_attrs)
    end

    context 'when license is nil' do
      let(:license) { nil }

      it { is_expected.to eq({}) }
    end

    context 'when user is nil' do
      let(:user) { nil }

      it { is_expected.to eq({}) }
    end

    context 'when not a trial' do
      let(:license) { build(:license, :ultimate) }

      it { is_expected.to eq({}) }
    end

    context 'when not an ultimate trial' do
      let(:license) { build(:license, :trial) }

      it { is_expected.to eq({}) }
    end

    context 'when trial has expired' do
      context 'when outside the time frame for the expiration widget' do
        let(:license) { build(:license, :ultimate_trial, expired: true) }

        it { is_expected.to eq({}) }
      end

      context 'in the time frame for the expiration widget' do
        let(:trial_duration) { -3 }
        let(:license) { build(:license, :ultimate_trial, recently_expired: true) }

        it 'returns correct attributes' do
          trial_widget_data_attrs = {
            trial_type: 'self_managed_ultimate',
            trial_days_used: 1,
            days_remaining: trial_duration,
            percentage_complete: -33.33,
            trial_discover_page_path: admin_discover_premium_path,
            purchase_now_url: promo_pricing_url(query: { deployment: 'self-managed' }),
            feature_id: described_class::EXPIRED_TRIAL_WIDGET
          }

          expect(attributes).to eq(trial_widget_data_attrs: trial_widget_data_attrs)
        end

        context 'when widget is dismissed' do
          let(:user) do
            build(:user, callouts: [build(:callout, feature_name: described_class::EXPIRED_TRIAL_WIDGET)])
          end

          it { is_expected.to eq({}) }
        end
      end
    end
  end
end
