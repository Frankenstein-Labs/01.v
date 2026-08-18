# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Config, feature_category: :system_access do
  let(:base_url) { 'https://example.com' }

  before do
    described_class.clear_memoization(:parsed_uri)

    allow(Gitlab.config.cloud_connector).to receive(:base_url).and_return(base_url)
  end

  describe '.base_url' do
    it 'returns the base_url from Gitlab.config.cloud_connector' do
      expect(described_class.base_url).to eq(base_url)
    end
  end

  describe '.host' do
    it 'returns the host component of the base URL' do
      expect(described_class.host).to eq('example.com')
    end
  end

  describe '.port' do
    context 'with no port set' do
      it 'returns the default port matching the URL scheme' do
        expect(described_class.port).to eq(443)
      end
    end

    context 'with port set' do
      let(:base_url) { 'https://example.com:8080' }

      it 'returns the given port' do
        expect(described_class.port).to eq(8080)
      end
    end
  end
end
