# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Nats, feature_category: :audit_events do
  let(:nats_config) { { 'servers' => ['nats://127.0.0.1:4222'] } }

  before do
    allow(Settings).to receive(:[]).and_call_original
    allow(Settings).to receive(:[]).with('nats').and_return(nats_config)
  end

  after do
    described_class.instance_variable_set(:@client, nil)
  end

  describe '.configured?' do
    context 'when NATS connection settings are present' do
      it { expect(described_class.configured?).to be(true) }
    end

    context 'when the nats settings block is absent' do
      let(:nats_config) { nil }

      it { expect(described_class.configured?).to be(false) }
    end

    context 'when servers are empty' do
      let(:nats_config) { { 'servers' => [] } }

      it { expect(described_class.configured?).to be(false) }
    end
  end

  describe '.enabled?' do
    context 'when not configured' do
      let(:nats_config) { nil }

      it { expect(described_class.enabled?).to be(false) }
    end

    context 'when configured' do
      context 'when the application setting is not present' do
        it 'returns false' do
          settings_without_nats = instance_double(ApplicationSetting)
          allow(settings_without_nats).to receive(:respond_to?).and_return(false)
          allow(::Gitlab::CurrentSettings).to receive(:current_application_settings)
            .and_return(settings_without_nats)

          expect(described_class.enabled?).to be(false)
        end
      end

      context 'when the application setting is enabled' do
        before do
          stub_application_setting(use_nats_for_audit_streaming: true)
        end

        it { expect(described_class.enabled?).to be(true) }
      end

      context 'when the application setting is disabled' do
        before do
          stub_application_setting(use_nats_for_audit_streaming: false)
        end

        it { expect(described_class.enabled?).to be(false) }
      end
    end
  end

  describe '.connection_options' do
    it 'resolves servers from settings' do
      expect(described_class.send(:connection_options)).to include(servers: ['nats://127.0.0.1:4222'])
    end

    it 'omits absent optional keys' do
      expect(described_class.send(:connection_options)).not_to have_key(:tls)
    end

    context 'with tls and connect_timeout configured' do
      let(:nats_config) do
        {
          'servers' => ['nats://127.0.0.1:4222'],
          'tls' => {
            'ca_file' => '/path/ca.pem',
            'cert' => '/path/client-cert.pem',
            'key' => '/path/client-key.pem'
          },
          'connect_timeout' => 5
        }
      end

      it 'normalizes the mutual-TLS options and passes connect_timeout through' do
        expect(described_class.send(:connection_options)).to include(
          tls: {
            ca_file: '/path/ca.pem',
            cert: '/path/client-cert.pem',
            key: '/path/client-key.pem'
          },
          connect_timeout: 5
        )
      end
    end

    context 'with only a CA file configured' do
      let(:nats_config) do
        {
          'servers' => ['nats://127.0.0.1:4222'],
          'tls' => { 'ca_file' => '/path/ca.pem' }
        }
      end

      it 'carries just the CA' do
        expect(described_class.send(:connection_options)[:tls]).to eq(ca_file: '/path/ca.pem')
      end
    end
  end

  describe '.client' do
    it 'memoizes a configured client' do
      client = described_class.client

      expect(client).to be_a(Gitlab::Nats::Client)
      expect(described_class.client).to equal(client)
    end
  end

  describe '.reset_client!' do
    it 'closes and clears the memoized client' do
      client = described_class.client
      expect(client).to receive(:close)

      described_class.reset_client!

      expect(described_class.client).not_to equal(client)
    end
  end
end
