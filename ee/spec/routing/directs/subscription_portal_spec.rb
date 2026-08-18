# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Custom URLs', 'Subscription Portal', feature_category: :subscription_management do
  include SubscriptionPortalHelper

  let(:env_value) { nil }

  before do
    stub_env('CUSTOMER_PORTAL_URL', env_value)
  end

  describe 'subscription_portal_legacy_sign_in_url' do
    subject { subscription_portal_legacy_sign_in_url }

    it { is_expected.to eq("#{staging_customers_url}/customers/sign_in?legacy=true") }
  end

  describe 'subscription_portal_manage_url' do
    subject { subscription_portal_manage_url }

    it { is_expected.to eq("#{staging_customers_url}/subscriptions") }
  end

  describe 'subscription_portal_graphql_url' do
    subject { subscription_portal_graphql_url }

    it { is_expected.to eq("#{staging_customers_url}/graphql") }
  end

  describe 'subscription_portal_more_minutes_url' do
    subject { subscription_portal_more_minutes_url }

    it { is_expected.to eq("#{staging_customers_url}/buy_pipeline_minutes") }
  end

  describe 'subscription_portal_more_storage_url' do
    subject { subscription_portal_more_storage_url }

    it { is_expected.to eq("#{staging_customers_url}/buy_storage") }
  end

  describe 'subscription_portal_gitlab_plans_url' do
    subject { subscription_portal_gitlab_plans_url }

    it { is_expected.to eq("#{staging_customers_url}/gitlab_plans") }
  end

  describe 'subscription_portal_edit_account_url' do
    subject { subscription_portal_edit_account_url }

    it { is_expected.to eq("#{staging_customers_url}/customers/edit") }
  end

  describe 'subscription_portal_billing_accounts_url' do
    subject { subscription_portal_billing_accounts_url }

    it { is_expected.to eq("#{staging_customers_url}/billing_accounts") }
  end

  describe 'subscription_portal_add_extra_seats_url' do
    let(:group_id) { 153 }

    subject { subscription_portal_add_extra_seats_url(group_id) }

    it { is_expected.to eq("#{staging_customers_url}/gitlab/namespaces/#{group_id}/extra_seats") }
  end

  describe 'subscription_portal_add_saas_duo_pro_seats' do
    let(:group_id) { 153 }

    subject { subscription_portal_add_saas_duo_pro_seats_url(group_id) }

    it { is_expected.to eq("#{staging_customers_url}/gitlab/namespaces/#{group_id}/duo_pro_seats") }
  end

  describe 'subscription_portal_add_sm_duo_pro_seats' do
    let(:subscription_name) { 'some_name' }

    subject { subscription_portal_add_sm_duo_pro_seats_url(subscription_name) }

    it { is_expected.to eq("#{staging_customers_url}/gitlab/subscriptions/#{subscription_name}/duo_pro_seats") }
  end

  describe 'subscription_portal_upgrade_subscription_url' do
    let(:group_id) { 153 }
    let(:plan_id) { 5 }

    subject { subscription_portal_upgrade_subscription_url(group_id, plan_id) }

    it { is_expected.to eq("#{staging_customers_url}/gitlab/namespaces/#{group_id}/upgrade/#{plan_id}") }
  end

  describe 'subscription_portal_renew_subscription_url' do
    let(:group_id) { 153 }

    subject { subscription_portal_renew_subscription_url(group_id) }

    it { is_expected.to eq("#{staging_customers_url}/gitlab/namespaces/#{group_id}/renew") }
  end

  describe 'subscription_portal_new_purchase_url' do
    subject { subscription_portal_new_purchase_url }

    it { is_expected.to eq("#{staging_customers_url}/subscriptions/purchases/gitlab") }
  end

  describe 'subscription_portal_gitlab_com_purchase_credits_url' do
    let(:group_id) { 123 }

    subject { subscription_portal_gitlab_com_purchase_credits_url(group_id) }

    it 'outputs the correct url' do
      is_expected.to eq(
        "#{subscription_portal_url}/subscriptions/purchases/gitlab" \
          "?deployment_type=gitlab_com&gl_namespace_id=#{group_id}&plan_type=gitlab_credits"
      )
    end
  end

  describe 'subscription_portal_self_managed_purchase_credits_url' do
    it 'outputs the correct base url without options' do
      expect(subscription_portal_self_managed_purchase_credits_url).to eq(
        "#{subscription_portal_url}/subscriptions/purchases/gitlab" \
          "?deployment_type=self_managed&plan_type=gitlab_credits"
      )
    end

    it 'add optiions params when provided' do
      expect(subscription_portal_self_managed_purchase_credits_url(subscription_name: 'A-123456')).to eq(
        "#{subscription_portal_url}/subscriptions/purchases/gitlab" \
          "?deployment_type=self_managed&plan_type=gitlab_credits&subscription_name=A-123456"
      )
    end

    it 'omits options when nil' do
      expect(subscription_portal_self_managed_purchase_credits_url(subscription_name: nil)).to eq(
        "#{subscription_portal_url}/subscriptions/purchases/gitlab" \
          "?deployment_type=self_managed&plan_type=gitlab_credits"
      )
    end
  end
end
