# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Tokens::TokenLoader, feature_category: :system_access do
  subject(:token_issuer) { described_class.new }

  describe '#token' do
    context 'when there are no active service access tokens' do
      before do
        allow(::CloudConnector::ServiceAccessToken).to receive(:active).and_return([])
      end

      it 'returns nil' do
        expect(token_issuer.token).to be_nil
      end
    end

    context 'when there are active service access tokens' do
      before do
        allow(::CloudConnector::ServiceAccessToken).to receive(:active).and_return([
          build(:service_access_token, :active, token: 'active_token_1'),
          build(:service_access_token, :active, token: 'active_token_2')
        ])
      end

      it 'returns the last active token' do
        expect(token_issuer.token).to eq('active_token_2')
      end
    end
  end
end
