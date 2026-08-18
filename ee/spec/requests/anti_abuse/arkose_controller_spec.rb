# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AntiAbuse::ArkoseController, :clean_gitlab_redis_sessions, feature_category: :instance_resiliency do
  include SessionHelpers

  describe 'GET #data_exchange_payload' do
    let_it_be(:user) { create(:user) }

    let(:mock_payload) { 'mock_payload' }

    subject(:do_request) { get data_exchange_payload_path }

    shared_examples 'returns an Arkose Data exchange payload for the correct use case' do |use_case|
      it 'returns an Arkose Data Exchange payload', :aggregate_failures do
        expect_next_instance_of(Arkose::DataExchangePayload, an_instance_of(ActionDispatch::Request),
          a_hash_including({ use_case: use_case, email: user.email })) do |instance|
          expect(instance).to receive(:build).and_return(mock_payload)
        end

        do_request

        expect(json_response['payload']).to eq mock_payload
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when user is not arkose_verified?' do
      let(:verification_user_id) { user.id }

      include_context 'with a signed-in IdentityVerificationUser'

      it_behaves_like 'returns an Arkose Data exchange payload for the correct use case',
        Arkose::DataExchangePayload::USE_CASE_SIGN_UP
    end

    context 'when user is arkose_verified?' do
      let_it_be(:user) { create(:user, :medium_risk) }

      before do
        login_as(user)
      end

      it_behaves_like 'returns an Arkose Data exchange payload for the correct use case',
        Arkose::DataExchangePayload::USE_CASE_IDENTITY_VERIFICATION
    end

    context 'when there is no signed-in user' do
      it 'returns 401' do
        do_request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it_behaves_like 'it handles absence of a signed-in IdentityVerificationUser' do
        it 'returns 401' do
          do_request

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end
    end
  end
end
