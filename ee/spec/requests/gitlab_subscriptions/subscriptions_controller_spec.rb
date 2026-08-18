# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionsController, :clean_gitlab_redis_sessions, feature_category: :subscription_management do
  include SessionHelpers

  shared_examples 'requires authentication' do
    it 'requires authentication' do
      request
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'GET /payment_form' do
    subject(:request) { get payment_form_subscriptions_path(id: 'payment-form-id') }

    it_behaves_like 'requires authentication'

    context 'when user is undergoing identity verification' do
      let_it_be(:unverified_user) { create(:user) }

      before do
        stub_session(session_data: { verification_user_id: unverified_user.id })
      end

      it 'skips authentication' do
        expect(Gitlab::SubscriptionPortal::Client)
          .to receive(:payment_form_params)
          .with('payment-form-id', nil)
          .and_return({ data: {} })

        request
        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when user has verified a credit card' do
        let!(:credit_card) { create(:credit_card_validation, user: unverified_user) }

        it_behaves_like 'requires authentication'
      end
    end
  end

  describe 'POST /validate_payment_method' do
    subject(:request) { post validate_payment_method_subscriptions_path(id: 'payment-method-id') }

    it_behaves_like 'requires authentication'

    context 'when user is undergoing identity verification' do
      let_it_be(:unverified_user) { create(:user) }

      before do
        stub_session(session_data: { verification_user_id: unverified_user.id })
      end

      it 'validates the payment method with the unverified user ID' do
        expect(Gitlab::SubscriptionPortal::Client)
          .to receive(:validate_payment_method)
          .with('payment-method-id', { gitlab_user_id: unverified_user.id })
          .and_return({})

        request
        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'when user has verified a credit card' do
        let!(:credit_card) { create(:credit_card_validation, user: unverified_user) }

        it_behaves_like 'requires authentication'
      end
    end

    context 'when the user is authenticated' do
      it 'validates the payment method with the authenticated user ID' do
        current_user = create(:user)

        sign_in(current_user)

        expect(Gitlab::SubscriptionPortal::Client)
          .to receive(:validate_payment_method)
          .with('payment-method-id', { gitlab_user_id: current_user.id })
          .and_return({})

        request
        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end
end
