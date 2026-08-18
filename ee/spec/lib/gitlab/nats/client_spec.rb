# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Nats::Client, feature_category: :audit_events do
  let(:servers) { ['nats://127.0.0.1:4222'] }
  let(:client) { described_class.new(servers: servers) }

  let(:connection) { instance_double(NATS::Client) }

  # NATS::JetStream gains its manager methods (stream_info, add_stream)
  # dynamically via `extend Manager` in #initialize, so a verifying
  # instance_double cannot see them; use a plain double instead.
  let(:jetstream) { double(:jetstream) } # rubocop:disable RSpec/VerifiedDoubles -- methods are added via extend at runtime

  before do
    allow(NATS).to receive(:connect).and_return(connection)
    allow(connection).to receive(:jetstream).and_return(jetstream)
  end

  describe '#initialize' do
    it 'requires servers' do
      expect { described_class.new(servers: []) }.to raise_error(ArgumentError, /servers must be present/)
    end
  end

  describe '#publish' do
    it 'publishes synchronously with the message-id dedup header' do
      pub_ack = instance_double(NATS::JetStream::PubAck)

      expect(jetstream).to receive(:publish).with(
        'audit_events.streaming.42',
        '{"id":"abc"}',
        timeout: described_class::DEFAULT_PUBLISH_TIMEOUT,
        header: { 'Nats-Msg-Id' => 'abc' }
      ).and_return(pub_ack)

      expect(client.publish('audit_events.streaming.42', '{"id":"abc"}', message_id: 'abc')).to eq(pub_ack)
    end

    it 'passes a custom timeout through' do
      expect(jetstream).to receive(:publish).with(
        'subject', 'payload', timeout: 0.5, header: { 'Nats-Msg-Id' => 'abc' }
      )

      client.publish('subject', 'payload', message_id: 'abc', timeout: 0.5)
    end

    it 'propagates ack timeouts' do
      allow(jetstream).to receive(:publish).and_raise(NATS::Timeout)

      expect { client.publish('subject', 'payload', message_id: 'abc') }.to raise_error(NATS::Timeout)
    end

    it 'connects lazily with reconnect options' do
      allow(jetstream).to receive(:publish)

      client.publish('subject', 'payload', message_id: 'abc')

      expect(NATS).to have_received(:connect).with(nil, hash_including(
        servers: servers,
        reconnect: true,
        max_reconnect_attempts: described_class::MAX_RECONNECT_ATTEMPTS
      ))
    end

    context 'with tls configured' do
      let(:cert_path) { Rails.root.join('spec/fixtures/clusters/sample_cert.pem').to_s }
      let(:key_path) { Rails.root.join('spec/fixtures/clusters/sample_key.key').to_s }
      let(:ca_path) { Rails.root.join('spec/fixtures/clusters/root_certificate.pem').to_s }

      let(:client) do
        described_class.new(servers: servers, tls: { ca_file: ca_path, cert: cert_path, key: key_path })
      end

      before do
        allow(jetstream).to receive(:publish)
      end

      it 'passes a prepared SSLContext to nats-pure (which ignores bare ca_file/cert/key)' do
        client.publish('subject', 'payload', message_id: 'abc')

        expect(NATS).to have_received(:connect) do |_uri, options|
          context = options.dig(:tls, :context)

          expect(context).to be_a(OpenSSL::SSL::SSLContext)
          # The client certificate and key must be loaded so the client can
          # authenticate to a mutual-TLS (verify_and_map) NATS cluster; without
          # them the server aborts the handshake with "certificate required".
          expect(context.cert).to be_a(OpenSSL::X509::Certificate)
          expect(context.key).to be_a(OpenSSL::PKey::PKey)
          expect(context.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
        end
      end

      it 'does not set an extra chain for a single-certificate file' do
        client.publish('subject', 'payload', message_id: 'abc')

        expect(NATS).to have_received(:connect) do |_uri, options|
          expect(options.dig(:tls, :context).extra_chain_cert).to be_nil
        end
      end

      context 'when the cert file bundles the leaf with intermediates' do
        let(:cert_path) { Rails.root.join('spec/fixtures/clusters/chain_certificates.pem').to_s }

        it 'sends the intermediates as extra_chain_cert so the server can verify the chain' do
          client.publish('subject', 'payload', message_id: 'abc')

          expect(NATS).to have_received(:connect) do |_uri, options|
            context = options.dig(:tls, :context)

            # The first PEM block is the client (leaf) cert; the remaining
            # blocks are the intermediate chain.
            expect(context.cert.subject.to_s).to include('Test Leaf Cert')
            expect(context.extra_chain_cert.size).to eq(2)
            expect(context.extra_chain_cert).to all(be_a(OpenSSL::X509::Certificate))
          end
        end
      end

      context 'when only a CA is configured (no client cert/key)' do
        let(:client) { described_class.new(servers: servers, tls: { ca_file: ca_path }) }

        it 'still builds a verifying SSLContext' do
          client.publish('subject', 'payload', message_id: 'abc')

          expect(NATS).to have_received(:connect) do |_uri, options|
            context = options.dig(:tls, :context)

            expect(context).to be_a(OpenSSL::SSL::SSLContext)
            expect(context.cert).to be_nil
            expect(context.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
          end
        end
      end

      context 'when a configured file is missing or unreadable' do
        let(:client) do
          described_class.new(servers: servers, tls: { ca_file: ca_path, cert: '/does/not/exist.pem', key: key_path })
        end

        it 'raises at connect time rather than silently connecting without a cert' do
          expect { client.publish('subject', 'payload', message_id: 'abc') }
            .to raise_error(Errno::ENOENT)
          expect(NATS).not_to have_received(:connect)
        end
      end

      context 'when the cert file contains no certificate (e.g. a key file was passed)' do
        let(:cert_path) { Rails.root.join('spec/fixtures/clusters/sample_key.key').to_s }

        it 'raises a clear error at connect time rather than connecting without a cert' do
          expect { client.publish('subject', 'payload', message_id: 'abc') }
            .to raise_error(described_class::Error, /no certificate found/)
          expect(NATS).not_to have_received(:connect)
        end
      end
    end

    context 'without tls' do
      it 'does not set the tls option' do
        allow(jetstream).to receive(:publish)

        client.publish('subject', 'payload', message_id: 'abc')

        expect(NATS).to have_received(:connect) do |_uri, options|
          expect(options).not_to have_key(:tls)
        end
      end
    end
  end

  describe '#pull_subscribe' do
    it 'binds a durable pull consumer' do
      # NATS::JetStream::PullSubscription is a private constant
      subscription = double(:pull_subscription) # rubocop:disable RSpec/VerifiedDoubles -- private constant in nats-pure

      expect(jetstream).to receive(:pull_subscribe)
        .with('audit_events.streaming.>', 'audit-events-consumer', {})
        .and_return(subscription)

      expect(client.pull_subscribe('audit_events.streaming.>', durable: 'audit-events-consumer'))
        .to eq(subscription)
    end

    it 'passes an explicit stream through' do
      expect(jetstream).to receive(:pull_subscribe)
        .with('subject', 'durable', { stream: 'audit_events' })

      client.pull_subscribe('subject', durable: 'durable', stream: 'audit_events')
    end
  end

  describe '#stream_info' do
    it 'returns the stream info' do
      info = double('StreamInfo') # rubocop:disable RSpec/VerifiedDoubles -- nats-pure API object, not a GitLab class
      expect(jetstream).to receive(:stream_info).with('audit_events_streaming').and_return(info)

      expect(client.stream_info('audit_events_streaming')).to eq(info)
    end

    it 'returns nil when the stream does not exist' do
      expect(jetstream).to receive(:stream_info).and_raise(NATS::JetStream::Error::NotFound)

      expect(client.stream_info('missing')).to be_nil
    end
  end

  describe '#add_stream' do
    it 'creates a stream from a config hash' do
      config = { name: 'audit_events_streaming', subjects: ['audit_events.streaming.*'] }
      expect(jetstream).to receive(:add_stream).with(**config)

      client.add_stream(config)
    end
  end

  describe '#update_stream' do
    it 'updates a stream from a config hash' do
      config = { name: 'audit_events_streaming', num_replicas: 3 }
      expect(jetstream).to receive(:update_stream).with(**config)

      client.update_stream(config)
    end
  end

  describe '#connected?' do
    it 'is false before any connection is made' do
      expect(client.connected?).to be(false)
    end

    it 'reflects the underlying connection state' do
      allow(jetstream).to receive(:publish)
      allow(connection).to receive(:connected?).and_return(true)

      client.publish('subject', 'payload', message_id: 'abc')

      expect(client.connected?).to be(true)
    end
  end

  describe '#close' do
    it 'closes the underlying connection and resets state' do
      allow(jetstream).to receive(:publish)
      client.publish('subject', 'payload', message_id: 'abc')

      expect(connection).to receive(:close)

      client.close

      expect(client.connected?).to be(false)
    end

    it 'is a no-op when never connected' do
      expect { client.close }.not_to raise_error
    end
  end
end
