# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoAmazonQAlertComponent, feature_category: :subscription_management do
  let(:user) { build_stubbed(:user) }
  let(:gitlab_com_subscriptions_enabled) { false }
  let(:add_on_purchase) { build_stubbed(:gitlab_subscription_add_on_purchase) }
  let(:dismissed_callout?) { false }

  subject(:component) { render_inline(described_class.new(user: user)) && page }

  before do
    stub_saas_features(gitlab_com_subscriptions: gitlab_com_subscriptions_enabled)
    allow(GitlabSubscriptions::DuoAmazonQ).to receive(:any_add_on_purchase).and_return(add_on_purchase)
  end

  context 'when alert renders' do
    it { is_expected.to have_content(s_('AmazonQ|GitLab Duo with Amazon Q')) }

    context 'when subscription is active' do
      it { is_expected.to have_content(s_('AmazonQ|GitLab Duo with Amazon Q - Subscription ends on')) }
    end

    context 'when subscription is expired' do
      let(:add_on_purchase) { build_stubbed(:gitlab_subscription_add_on_purchase, :expired) }

      it { is_expected.to have_content(s_('AmazonQ|Your GitLab Duo with Amazon Q subscription has ended')) }
      it { is_expected.to have_css('.gl-alert-danger') }
    end

    context 'when active and not close to expiry' do
      let(:add_on_purchase) { build_stubbed(:gitlab_subscription_add_on_purchase, expires_on: 18.days.from_now) }

      it { is_expected.to have_css('.gl-alert-info') }
    end

    context 'when active and closer to expiry' do
      let(:add_on_purchase) { build_stubbed(:gitlab_subscription_add_on_purchase, expires_on: 14.days.from_now) }

      it { is_expected.to have_css('.gl-alert-warning') }
    end

    context 'when active and within a few days of expiry' do
      let(:add_on_purchase) { build_stubbed(:gitlab_subscription_add_on_purchase, expires_on: 1.day.from_now) }

      it { is_expected.to have_css('.gl-alert-danger') }
    end
  end

  context 'when component does not render' do
    context 'when instance is SaaS' do
      let(:gitlab_com_subscriptions_enabled) { true }

      it { is_expected.not_to have_content(s_('AmazonQ|GitLab Duo with Amazon Q')) }
    end

    context 'when user has dismissed the alert' do
      let(:user) do
        build_stubbed(
          :user,
          callouts: [
            build_stubbed(
              :callout,
              feature_name: 'duo_amazon_q_alert',
              dismissed_at: 1.day.ago
            )
          ]
        )
      end

      it { is_expected.not_to have_content(s_('AmazonQ|GitLab Duo with Amazon Q')) }
    end

    context 'when add-on purchase is not found' do
      let(:add_on_purchase) { nil }

      it { is_expected.not_to have_content(s_('AmazonQ|GitLab Duo with Amazon Q')) }
    end
  end
end
