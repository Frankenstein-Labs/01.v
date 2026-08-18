# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::AddOnStatus, :saas, feature_category: :subscription_management do
  describe '#show?' do
    let(:group) { build(:group) }

    let(:add_on_purchase) do
      build(:gitlab_subscription_add_on_purchase, :duo_pro, :active_trial, namespace: group)
    end

    subject { described_class.new(add_on_purchase: add_on_purchase).show? }

    it { is_expected.to be(true) }

    context 'without a duo pro trial add on' do
      let(:add_on_purchase) { nil }

      it { is_expected.to be(false) }
    end

    context 'with an expired duo pro trial add on' do
      context 'when on 10th day of expiration' do
        it 'returns true' do
          add_on_purchase.expires_on = 9.days.ago

          is_expected.to be(true)
        end
      end

      context 'when on 11th day of expiration' do
        it 'returns false' do
          add_on_purchase.expires_on = 10.days.ago

          is_expected.to be(false)
        end
      end
    end

    context 'with an expired ultimate trial' do
      let(:trial_starts_on) { 2.days.ago }
      let(:trial_ends_on) { 1.day.ago }
      let(:duo_pro_expires_on) { 1.day.ago }
      let(:trial_duration) { 60 }

      before do
        gitlab_subscription = build(:gitlab_subscription, :ultimate, namespace: group)
        gitlab_subscription.trial_starts_on = trial_starts_on
        gitlab_subscription.trial_ends_on = trial_ends_on
        add_on_purchase.expires_on = duo_pro_expires_on
      end

      it { is_expected.to be(true) }

      context 'with an expired duo pro trial add on' do
        let(:duo_pro_expires_on) { trial_duration.days.ago + 1.day.ago }

        it { is_expected.to be(true) }
      end
    end
  end
end
