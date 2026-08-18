# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Users, :aggregate_failures, :api, feature_category: :subscription_management do
  include CryptoHelpers
  include GitlabSubscriptions::InternalApiHelpers

  describe 'GET /internal/gitlab_subscriptions/users/:id' do
    let_it_be(:user) { create(:user) }

    def users_path(user_id)
      internal_api("users/#{user_id}")
    end

    context 'when unauthenticated' do
      it 'returns authentication error' do
        get users_path(user.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the user exists' do
        it 'returns success' do
          get users_path(user.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)

          expect(json_response["id"]).to eq(user.id)
          expect(json_response.keys).to eq(%w[id username public_email name web_url])
        end
      end

      context 'when user does not exists' do
        it 'returns not found' do
          get users_path(non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq("404 User Not Found")
        end
      end
    end
  end

  describe "PUT /internal/gitlab_subscriptions/users/:user_id/credit_card_validation" do
    let_it_be(:user) { create(:user) }
    let_it_be(:admin) { create(:admin) }
    let(:network) { 'American Express' }
    let(:holder_name) {  'John Smith' }
    let(:last_digits) {  '1111' }
    let(:expiration_year) { Date.today.year + 10 }
    let(:expiration_month) { 1 }
    let(:expiration_date) { Date.new(expiration_year, expiration_month, -1) }
    let(:credit_card_validated_at) { Time.utc(2020, 1, 1) }
    let(:zuora_payment_method_xid) { 'abc123' }
    let(:stripe_setup_intent_xid) { 'seti_abc123' }
    let(:stripe_payment_method_xid) { 'pm_abc123' }
    let(:stripe_card_fingerprint) { 'card123' }

    let(:path) { internal_api("users/#{user.id}/credit_card_validation") }
    let(:params) do
      {
        credit_card_validated_at: credit_card_validated_at,
        credit_card_expiration_year: expiration_year,
        credit_card_expiration_month: expiration_month,
        credit_card_holder_name: holder_name,
        credit_card_type: network,
        credit_card_mask_number: last_digits,
        zuora_payment_method_xid: zuora_payment_method_xid,
        stripe_setup_intent_xid: stripe_setup_intent_xid,
        stripe_payment_method_xid: stripe_payment_method_xid,
        stripe_card_fingerprint: stripe_card_fingerprint
      }
    end

    context 'when unauthenticated' do
      it 'returns authentication error' do
        put path, params: {}

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as subscription portal' do
      before do
        stub_internal_api_authentication
      end

      it "updates user's credit card validation" do
        put path, params: params, headers: internal_api_headers

        user.reload

        expect(response).to have_gitlab_http_status(:ok)
        expect(user.credit_card_validation).to have_attributes(
          credit_card_validated_at: credit_card_validated_at,
          network_hash: sha256(network.downcase),
          holder_name_hash: sha256(holder_name.downcase),
          last_digits_hash: sha256(last_digits),
          expiration_date_hash: sha256(expiration_date.to_s),
          zuora_payment_method_xid: zuora_payment_method_xid,
          stripe_setup_intent_xid: stripe_setup_intent_xid,
          stripe_payment_method_xid: stripe_payment_method_xid,
          stripe_card_fingerprint: stripe_card_fingerprint
        )
      end

      context 'when the params are not correct' do
        let(:stripe_payment_method_xid) { SecureRandom.hex(130) }

        it "returns 400 error if stripe_payment_method_xid is too long" do
          put path, params: params, headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      it 'returns 404 error if user not found' do
        put api("/user/#{non_existing_record_id}/credit_card_validation", admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 User Not Found')
      end
    end
  end

  describe 'GET /internal/gitlab_subscriptions/namespaces/:namespace_id/user_permissions/:user_id' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:user) { create(:user) }

    def user_permissions_path(namespace_id, user_id)
      internal_api("namespaces/#{namespace_id}/user_permissions/#{user_id}")
    end

    context 'when unauthenticated' do
      it 'returns an authentication error' do
        get user_permissions_path(namespace.id, user.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the user can manage the namespace billing' do
        it 'returns true for edit_billing' do
          namespace.add_owner(user)

          get user_permissions_path(namespace.id, user.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['edit_billing']).to be true
        end
      end

      context 'when the user cannot manage the namespace billing' do
        it 'returns false for edit_billing' do
          get user_permissions_path(namespace.id, user.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['edit_billing']).to be false
        end
      end

      context 'when the namespace does not exist' do
        it 'returns a not found response' do
          get user_permissions_path(non_existing_record_id, user.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the user does not exist' do
        it 'returns a not found response' do
          get user_permissions_path(namespace.id, non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
