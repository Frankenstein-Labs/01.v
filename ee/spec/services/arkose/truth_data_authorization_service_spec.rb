# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arkose::TruthDataAuthorizationService, feature_category: :instance_resiliency do
  let(:access_token) { '1235abcde' }
  let(:authorize_api_status_code) { 200 }

  before do
    stub_request(:post, Arkose::TruthDataAuthorizationService::TRUTH_DATA_AUTHORIZATION_ENDPOINT)
      .with(
        body: /.*/,
        headers: {
          'Accept' => '*/*'
        }
      ).to_return(
        status: authorize_api_status_code,
        body: { 'access_token' => access_token, 'token_type' => 'Bearer', 'expires_in' => 86400 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '.execute' do
    subject(:execute) { described_class.execute }

    before do
      allow(Rails.cache).to receive(:write)
    end

    shared_examples 'fetches a new token' do
      it { is_expected.to be_success }

      it 'returns an authorization token' do
        response = execute

        expect(response.payload[:token]).to eq(access_token)
      end

      it 'sends a token API request' do
        execute

        expect(WebMock).to have_requested(
          :post,
          Arkose::TruthDataAuthorizationService::TRUTH_DATA_AUTHORIZATION_ENDPOINT
        )
      end

      it 'caches the token' do
        expect(Rails.cache).to receive(:write).with(
          Arkose::TruthDataAuthorizationService::AUTHORIZATION_TOKEN_CACHE_KEY,
          access_token,
          expires_in: 86340
        )

        execute
      end
    end

    shared_examples 'returns a cached token' do
      it { is_expected.to be_success }

      it 'returns an authorization token' do
        response = execute

        expect(response.payload[:token]).to eq(access_token)
      end

      it 'does not send a token API request' do
        execute

        expect(WebMock).not_to have_requested(
          :post,
          Arkose::TruthDataAuthorizationService::TRUTH_DATA_AUTHORIZATION_ENDPOINT
        )
      end

      it 'does not cache the token' do
        expect(Rails.cache).not_to receive(:write)

        execute
      end
    end

    it_behaves_like 'fetches a new token'

    context 'when the token has already been cached' do
      before do
        allow(Rails.cache).to receive(:fetch).with(
          Arkose::TruthDataAuthorizationService::AUTHORIZATION_TOKEN_CACHE_KEY
        ).and_return(access_token)
      end

      it_behaves_like 'returns a cached token'
    end

    context 'when the token request fails' do
      let(:authorize_api_status_code) { 400 }

      it 'does not write to cache' do
        expect(Rails.cache).not_to receive(:write)

        execute
      end

      it 'returns an error response' do
        response = execute

        expect(response).to be_error
        expect(response.message).to eq("Unable to fetch authorization token. Response code: 400")
      end
    end
  end
end
