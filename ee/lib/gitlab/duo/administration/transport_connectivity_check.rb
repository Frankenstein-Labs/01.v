# frozen_string_literal: true

require 'socket'
require 'openssl'

module Gitlab
  module Duo
    module Administration
      class TransportConnectivityCheck
        TLS_MISMATCH_ERROR_PATTERN =
          ::CloudConnector::StatusChecks::Probes::DuoAgentPlatformProbe::TLS_MISMATCH_ERROR_PATTERN

        CONNECT_TIMEOUT = 10
        PROXY_ENV_VARS = %w[
          HTTP_PROXY http_proxy HTTPS_PROXY https_proxy NO_PROXY no_proxy grpc_proxy no_grpc_proxy
        ].freeze

        SelfHostedFeatureSetting = Struct.new(:self_hosted?)

        Result = Struct.new(
          :name, :host, :port, :tls, :status, :tls_verified, :cert_subject, :cert_issuer,
          :proxy, :error, :response_time_ms, keyword_init: true
        ) do
          def ok?
            status == :ok
          end

          def tls_mismatch?
            return false unless error && tls

            error.message.match?(TLS_MISMATCH_ERROR_PATTERN)
          end
        end

        def execute
          [ai_gateway_result, duo_agent_platform_result].compact
        end

        def proxy_environment
          PROXY_ENV_VARS.each_with_object({}) do |name, memo|
            value = ENV[name].presence
            memo[name] = value if value
          end
        end

        private

        def ai_gateway_result
          url = ::Gitlab::AiGateway.self_hosted_url
          return if url.blank?

          uri = URI.parse(url)
          return if uri.host.blank?

          probe_endpoint(name: 'AI Gateway', host: uri.host, port: uri.port, tls: uri.is_a?(URI::HTTPS))
        rescue URI::InvalidURIError
          nil
        end

        def duo_agent_platform_result
          url = ::Gitlab::DuoWorkflow::Client.self_hosted_url
          return if url.blank?

          host, _, port = url.rpartition(':')
          return if host.blank? || port.blank?

          probe_endpoint(name: 'GitLab Duo Agent Platform (gRPC)', host: host, port: port.to_i, tls: grpc_secure?)
        end

        def grpc_secure?
          ::Gitlab::DuoWorkflow::Client.secure?(feature_setting: SelfHostedFeatureSetting.new(true))
        end

        def probe_endpoint(name:, host:, port:, tls:)
          started_at = Time.current
          cert = nil
          tls_verified = nil

          if tls
            ssl_socket, tls_verified = open_tls_socket(host, port)

            begin
              cert = ssl_socket.peer_cert
              ssl_socket.post_connection_check(host) if tls_verified
            ensure
              ssl_socket.close
            end
          else
            tcp_socket(host, port).close
          end

          Result.new(
            name: name, host: host, port: port, tls: tls, status: :ok,
            tls_verified: tls_verified, cert_subject: cert&.subject&.to_s, cert_issuer: cert&.issuer&.to_s,
            proxy: proxy_for(host, port, tls), response_time_ms: elapsed_ms(started_at)
          )
        rescue StandardError => e
          Result.new(
            name: name, host: host, port: port, tls: tls, status: :error,
            error: e, proxy: proxy_for(host, port, tls), response_time_ms: elapsed_ms(started_at)
          )
        end

        def open_tls_socket(host, port)
          [tls_socket(host, port, OpenSSL::SSL::VERIFY_PEER, cert_store), true]
        rescue OpenSSL::SSL::SSLError => e
          raise unless certificate_verification_error?(e)

          [tls_socket(host, port, OpenSSL::SSL::VERIFY_NONE, nil), false]
        end

        def certificate_verification_error?(error)
          error.message.match?(/certificate verify failed/i)
        end

        def tls_socket(host, port, verify_mode, store)
          context = OpenSSL::SSL::SSLContext.new
          context.verify_mode = verify_mode
          context.cert_store = store if store

          tcp = tcp_socket(host, port)
          ssl = OpenSSL::SSL::SSLSocket.new(tcp, context)
          ssl.hostname = host
          ssl.sync_close = true
          ssl.connect
          ssl
        rescue StandardError
          tcp&.close
          raise
        end

        def tcp_socket(host, port)
          Socket.tcp(host, port, connect_timeout: CONNECT_TIMEOUT)
        end

        def cert_store
          store = OpenSSL::X509::Store.new
          store.set_default_paths

          ::Gitlab::X509::Certificate.load_ca_certs_bundle(::Gitlab::X509::Certificate.ca_certs_bundle).each do |cert|
            store.add_cert(cert)
          rescue OpenSSL::X509::StoreError
            next
          end

          store
        end

        def elapsed_ms(started_at)
          ((Time.current - started_at) * 1000).round(2)
        end

        def proxy_for(host, port, tls)
          scheme = tls ? 'https' : 'http'
          URI("#{scheme}://#{host}:#{port}").find_proxy&.to_s
        rescue StandardError
          nil
        end
      end
    end
  end
end
