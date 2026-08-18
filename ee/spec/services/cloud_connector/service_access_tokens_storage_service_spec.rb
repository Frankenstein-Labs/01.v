# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::ServiceAccessTokensStorageService, :freeze_time, feature_category: :system_access do
  before do
    create(:service_access_token, :expired)
    create(:service_access_token, :expired)
    create(:service_access_token, :active)
  end

  describe '#execute' do
    shared_examples 'cleans up all tokens' do
      it 'removes all tokens' do
        expect { service_token_storage_service }.to change { CloudConnector::ServiceAccessToken.count }.to(0)
      end

      it 'logs that it cleans up all tokens' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'service_access_tokens',
          action: 'cleanup_all'
        )

        service_token_storage_service
      end
    end

    shared_examples 'generates_new_token' do
      it 'creates a new token' do
        expect(service_token_storage_service.success?).to eq(true)

        service_token = CloudConnector::ServiceAccessToken.last
        expect(service_token.token).to eq(token)
        expect(service_token.expires_at).to eq(expected_expired_at)
      end

      it 'cleans up all expired tokens' do
        expect { subject }.to change { CloudConnector::ServiceAccessToken.expired.count }.to(0)
      end

      it 'logs the actions it takes' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'service_access_tokens',
          action: 'created',
          expires_at: expected_expired_at
        ).ordered

        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'service_access_tokens',
          action: 'cleanup_expired'
        ).ordered

        service_token_storage_service
      end
    end

    let_it_be(:token) { 'token' }
    let(:expires_at) { (Time.current + 1.day).iso8601 }
    let(:expected_expired_at) { Time.iso8601(expires_at) }

    subject(:service_token_storage_service) { described_class.new(token, expires_at).execute }

    context 'when token and expires_at are present' do
      include_examples 'generates_new_token'

      context 'when expires_at is numerical' do
        let(:expires_at) { Time.current.to_i + 1.day.to_i }
        let(:expected_expired_at) { Time.at(expires_at, in: '+00:00') }

        include_examples 'generates_new_token'
      end

      context 'when it fails to create a token' do
        let_it_be(:expires_at) { 'not_a_real_date' }

        it 'tracks the error' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(ArgumentError))

          expect(service_token_storage_service.success?).to eq(false)
        end
      end
    end

    context 'when token is not present' do
      let_it_be(:token) { nil }

      include_examples 'cleans up all tokens'
    end

    context 'when expires_at is not present' do
      let(:expires_at) { nil }

      include_examples 'cleans up all tokens'
    end
  end
end
