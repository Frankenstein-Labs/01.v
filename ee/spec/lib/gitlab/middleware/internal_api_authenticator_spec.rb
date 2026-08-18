# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Middleware::InternalApiAuthenticator, feature_category: :api do
  let(:request) { instance_double(ActionDispatch::Request, path: '', env: {}) }

  before do
    allow(Gitlab.config.gitlab).to receive(:relative_url_root).and_return('')
  end

  describe '#verify!' do
    subject(:authenticator) { described_class.new(request) }

    describe 'GitLab Subscriptions (CustomersDot)' do
      before do
        allow(request).to receive_messages(path: '/api/v4/internal/gitlab_subscriptions/sync', env: {})
      end

      context 'when authentication succeeds' do
        it 'returns true' do
          expect(::GitlabSubscriptions::API::Internal::Auth).to receive(:verify_api_request).and_return(true)

          expect(authenticator.verify!).to be_truthy
        end
      end

      context 'when authentication fails' do
        it 'returns false' do
          expect(::GitlabSubscriptions::API::Internal::Auth).to receive(:verify_api_request).and_return(false)

          expect(authenticator.verify!).to be_falsey
        end
      end

      context 'when an error occurs' do
        it 'logs and returns false' do
          expect(::GitlabSubscriptions::API::Internal::Auth).to receive(:verify_api_request)
          .and_raise(StandardError.new('Auth error'))
          expect(Gitlab::AppLogger).to receive(:info)

          expect(authenticator.verify!).to be_falsey
        end
      end
    end
  end
end
