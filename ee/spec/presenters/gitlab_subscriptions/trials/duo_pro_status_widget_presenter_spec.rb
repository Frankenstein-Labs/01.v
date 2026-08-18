# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoProStatusWidgetPresenter, :saas, feature_category: :acquisition do
  let(:user) { build(:user) }
  let(:group) { build(:group) }
  let(:add_on_purchase) do
    build(:gitlab_subscription_add_on_purchase, :duo_pro, :active_trial, namespace: group)
  end

  before do
    build(:gitlab_subscription, :ultimate, namespace: group)
    allow(GitlabSubscriptions::Trials::DuoPro).to receive(:any_add_on_purchase_for_namespace)
    allow(GitlabSubscriptions::Trials::DuoPro)
      .to receive(:any_add_on_purchase_for_namespace).with(group).and_return(add_on_purchase)
  end

  describe '#attributes' do
    subject { described_class.new(group, user: user).attributes }

    let(:trial_duration) { 60 }

    specify do
      freeze_time do
        # set here to ensure no date barrier flakiness
        add_on_purchase.started_at = Time.current
        add_on_purchase.expires_on = trial_duration.days.from_now

        is_expected.to eq(
          trial_widget_data_attrs: {
            trial_type: 'duo_pro',
            trial_days_used: 1,
            days_remaining: trial_duration,
            percentage_complete: 1.67,
            group_id: group.id,
            trial_discover_page_path: group_add_ons_discover_duo_pro_path(group),
            purchase_now_url: ::Gitlab::Routing.url_helpers.subscription_portal_add_saas_duo_pro_seats_url(group.id),
            feature_id: described_class::EXPIRED_TRIAL_WIDGET
          }
        )
      end
    end
  end

  describe '#eligible_for_widget?' do
    let(:root_group) { group }
    let(:current_user) { user }

    subject { described_class.new(root_group, user: current_user).eligible_for_widget? }

    it { is_expected.to be(true) }

    context 'without a duo pro trial add on' do
      let(:root_group) { build(:group) }

      it { is_expected.to be(false) }
    end

    context 'when the widget is dismissed' do
      before do
        allow(user).to receive(:dismissed_callout_for_group?).and_return(true)
      end

      it { is_expected.to be(false) }
    end

    context 'when the widget is expired' do
      before do
        add_on_purchase.expires_on = 5.days.ago
      end

      it { is_expected.to be(true) }
    end
  end
end
