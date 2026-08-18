# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::CachingKeyLoader, feature_category: :system_access do
  let_it_be(:cc_key) { create(:cloud_connector_keys) }

  describe '.private_jwk' do
    before do
      allow(Gitlab::AppLogger).to receive(:info) # silence logger

      # Reset the memoized value before each test
      described_class.instance_variable_set(:@jwk, nil)
    end

    context 'when a valid key exists' do
      it 'loads and returns the signing key' do
        expect(described_class.private_jwk).to eq(cc_key.to_jwk)
      end

      it 'logs the key loading event' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: 'Cloud Connector key loaded',
          cc_kid: cc_key.to_jwk.kid
        )

        described_class.private_jwk
      end

      it 'memoizes the key' do
        expect(CloudConnector::Keys).to receive(:current).once.and_call_original

        first_call = described_class.private_jwk
        second_call = described_class.private_jwk

        expect(first_call).to eq(second_call)
      end
    end

    context 'when no key exists' do
      before do
        ::CloudConnector::Keys.delete_all
      end

      it 'raises an error' do
        expect { described_class.private_jwk }.to raise_error(
          RuntimeError,
          'Cloud Connector: no key found'
        )
      end
    end
  end

  describe '#private_jwk' do
    it 'delegates to the class method' do
      instance = described_class.new

      expect(instance.private_jwk).to eq(described_class.private_jwk)
    end
  end
end
