# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoEnterpriseStatusWidgetPresenter, :saas, feature_category: :acquisition do
  let(:user) { build(:user) }
  let(:namespace) { build(:group) }
  let(:plan) { :ultimate }
  let(:add_on_purchase) do
    build(:gitlab_subscription_add_on_purchase, :duo_enterprise, :active_trial, namespace: namespace)
  end

  let(:presenter) { described_class.new(namespace, user: user) }

  before do
    build(:gitlab_subscription, plan, namespace: namespace)
    allow(GitlabSubscriptions::Trials::DuoEnterprise)
      .to receive(:any_add_on_purchase_for_namespace).with(namespace).and_return(add_on_purchase)
  end

  describe '#eligible_for_widget?' do
    subject(:eligible_for_widget) { presenter.eligible_for_widget? }

    let(:duo_enterprise_status) { instance_double(GitlabSubscriptions::Trials::AddOnStatus, show?: true) }

    before do
      allow(GitlabSubscriptions::Trials::AddOnStatus).to receive(:new).and_return(duo_enterprise_status)
      allow(user).to receive(:dismissed_callout_for_group?).and_return(false)
    end

    it { is_expected.to be(true) }

    context 'when the namespace is not on an eligible plan' do
      let(:plan) { :free }

      it { is_expected.to be(false) }
    end

    context 'when duo enterprise status is not shown' do
      before do
        allow(duo_enterprise_status).to receive(:show?).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'when the widget is dismissed' do
      before do
        allow(user).to receive(:dismissed_callout_for_group?).and_return(true)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#attributes' do
    subject(:attributes) { presenter.attributes }

    let(:trial_duration) { 60 }

    it 'returns the correct attributes' do
      freeze_time do
        add_on_purchase.started_at = Time.current
        add_on_purchase.expires_on = trial_duration.days.from_now

        expect(attributes).to eq({
          trial_widget_data_attrs: {
            trial_type: "duo_enterprise",
            trial_days_used: 1,
            days_remaining: trial_duration,
            percentage_complete: 1.67,
            group_id: namespace.id,
            trial_discover_page_path: group_add_ons_discover_duo_enterprise_path(namespace),
            purchase_now_url: subscription_portal_url,
            feature_id: described_class::EXPIRED_TRIAL_WIDGET
          }
        })
      end
    end
  end
end
