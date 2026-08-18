# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::CustomersPortalRedirectController, :clean_gitlab_redis_sessions, feature_category: :onboarding do
  include SessionHelpers

  let_it_be(:user) { create(:user, onboarding_status_registration_type: 'subscription_sm') }

  before do
    stub_saas_features(onboarding: true)
  end

  describe 'GET show' do
    let(:plan_id) { 'premium-plan-id' }
    let(:stored_path) do
      new_subscriptions_path(plan_id: plan_id, deployment_type: 'self_managed')
    end

    subject(:get_show) do
      get users_sign_up_customers_portal_redirect_path
      response
    end

    context 'when not signed in' do
      it { is_expected.to redirect_to(new_user_session_path) }
    end

    context 'when signed in' do
      before do
        sign_in(user)
        stub_session(session_data: { 'user_return_to' => stored_path })
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'renders the Customers Portal URL with self-managed deployment, plan_id, and auto_submit_sso' do
        get_show

        expect(response.body)
          .to include('deployment_type=self_managed')
          .and include("plan_id=#{plan_id}")
          .and include('auto_submit_sso=true')
      end

      context 'when onboarding is not enabled' do
        before do
          stub_saas_features(onboarding: false)
        end

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when the user is not a subscription or subscription_sm registration' do
        let_it_be(:user) { create(:user, onboarding_status_registration_type: 'invite') }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when no stored user location is present' do
        before do
          stub_session(session_data: {})
        end

        it 'still renders the page without purchase params' do
          get_show

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to include('auto_submit_sso=true')
          expect(response.body).not_to include('plan_id=')
          expect(response.body).not_to include('deployment_type=')
        end
      end

      context 'when user is a subscription_registration type' do
        let_it_be(:subscription_user) { create(:user, onboarding_status_registration_type: 'subscription') }
        let(:namespace_id) { 'namespace-id' }
        let(:stored_path) do
          "/-/subscriptions/new?plan_id=#{plan_id}&namespace_id=#{namespace_id}"
        end

        before do
          sign_out(user)
          sign_in(subscription_user)
          stub_session(session_data: { 'user_return_to' => stored_path })
        end

        it 'uses the subscription portal URL instead of purchase URL' do
          get_show

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to include('auto_submit_sso=true')
          expect(response.body).to include("plan_id=#{plan_id}")
          expect(response.body).to include("namespace_id=#{namespace_id}")
        end
      end
    end
  end
end
