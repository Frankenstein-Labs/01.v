# frozen_string_literal: true

module Gitlab
  module Nats
    # Thin, business-logic-free wrapper around the NATS JetStream client.
    #
    # This class is deliberately isolated: it has no knowledge of audit
    # events or any other GitLab domain, and it never reads GitLab
    # `Settings`, `Feature`, or application settings. All connection
    # configuration is injected through the constructor (resolved by
    # Gitlab::Nats.client). This keeps the contract swappable for an
    # infra-provided shared client and makes future gem extraction trivial.
    class Client
      DEFAULT_CONNECT_TIMEOUT = 2 # seconds
      DEFAULT_PUBLISH_TIMEOUT = 2.0 # seconds
      DEFAULT_FETCH_TIMEOUT = 5.0 # seconds
      MAX_RECONNECT_ATTEMPTS = 3
      RECONNECT_TIME_WAIT = 1 # seconds

      MESSAGE_ID_HEADER = 'Nats-Msg-Id'

      Error = Class.new(StandardError)

      def initialize(servers:, tls: nil, connect_timeout: DEFAULT_CONNECT_TIMEOUT)
        raise ArgumentError, 'servers must be present' if Array(servers).empty?

        @servers = Array(servers)
        @tls = tls
        @connect_timeout = connect_timeout
        @mutex = Mutex.new
      end

      # Synchronous JetStream publish. Blocks until the server acknowledges
      # the message or `timeout` elapses.
      #
      # @param subject [String] subject to publish to
      # @param payload [String] serialized message body
      # @param message_id [String] stable ID used for JetStream dedup
      #   (Nats-Msg-Id header) within the stream's duplicate window
      # @param timeout [Float] seconds to wait for the pub-ack
      # @return [NATS::JetStream::PubAck]
      # @raise [NATS::Timeout, NATS::JetStream::Error] on ack timeout or
      #   stream errors
      def publish(subject, payload, message_id:, timeout: DEFAULT_PUBLISH_TIMEOUT)
        jetstream.publish(
          subject,
          payload,
          timeout: timeout,
          header: { MESSAGE_ID_HEADER => message_id }
        )
      end

      # Binds (or creates) a durable pull consumer subscription.
      #
      # The returned subscription supports `fetch(batch_size, timeout:)`
      # returning an array of messages, each responding to `data`, `header`,
      # and `ack`.
      #
      # @param subject [String] subject filter to consume from
      # @param durable [String] durable consumer name
      # @param stream [String, nil] stream name; resolved by subject lookup
      #   when omitted
      # @return [NATS::JetStream::PullSubscription]
      def pull_subscribe(subject, durable:, stream: nil)
        params = {}
        params[:stream] = stream if stream

        jetstream.pull_subscribe(subject, durable, params)
      end

      # Returns the stream's info, or nil when the stream does not exist.
      #
      # @param name [String] stream name
      # @return [NATS::JetStream::API::StreamInfo, nil]
      def stream_info(name)
        jetstream.stream_info(name)
      rescue ::NATS::JetStream::Error::NotFound
        nil
      end

      # Creates a stream.
      #
      # @param config [Hash] JetStream stream configuration (name, subjects,
      #   retention, storage, num_replicas, max_age, duplicate_window, ...)
      # @return [NATS::JetStream::API::StreamCreateResponse]
      def add_stream(config)
        jetstream.add_stream(**config)
      end

      # Updates an existing stream's configuration.
      #
      # @param config [Hash] JetStream stream configuration
      # @return [NATS::JetStream::API::StreamCreateResponse]
      def update_stream(config)
        jetstream.update_stream(**config)
      end

      def connected?
        connection = @mutex.synchronize { @connection }

        !!connection&.connected?
      end

      def close
        @mutex.synchronize do
          @connection&.close
          @connection = nil
          @jetstream = nil
        end
      end

      private

      def jetstream
        @mutex.synchronize do
          @jetstream ||= connection.jetstream
        end
      end

      # Must be called while holding @mutex.
      def connection
        @connection ||= ::NATS.connect(nil, connect_options)
      end

      def connect_options
        options = {
          servers: @servers,
          connect_timeout: @connect_timeout,
          reconnect: true,
          max_reconnect_attempts: MAX_RECONNECT_ATTEMPTS,
          reconnect_time_wait: RECONNECT_TIME_WAIT
        }

        tls_context = build_tls_context
        # nats-pure ignores bare ca_file/cert/key; it only reads a prepared
        # SSLContext under `context:` (NATS::IO::Client#tls_context).
        options[:tls] = { context: tls_context } if tls_context

        options
      end

      def build_tls_context
        return unless @tls

        OpenSSL::SSL::SSLContext.new.tap do |context|
          context.set_params
          context.ca_file = @tls[:ca_file] if @tls[:ca_file]
          load_client_certificate(context) if @tls[:cert]
          context.key = OpenSSL::PKey.read(File.read(@tls[:key])) if @tls[:key]
          context.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
      end

      def load_client_certificate(context)
        # A cert file may bundle the leaf with intermediates; the leaf is the
        # client cert, the rest is the chain the server needs to verify it.
        leaf, *chain = ::Gitlab::X509::Certificate.load_ca_certs_bundle(File.read(@tls[:cert]))

        raise Error, "no certificate found in #{@tls[:cert]}" unless leaf

        context.cert = leaf
        context.extra_chain_cert = chain if chain.any?
      end
    end
  end
end
