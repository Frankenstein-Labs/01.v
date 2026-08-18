# frozen_string_literal: true

module SecretsManagement
  class SecretsManagerClient
    include Gitlab::Utils::StrongMemoize
    include SecretsManagement::Concerns::OpenbaoWarningHandling

    SERVER_VERSION_FILE = 'GITLAB_OPENBAO_VERSION'
    KV_VALUE_FIELD = 'value'
    DEFAULT_JWT_ROLE = 'app'
    GITLAB_JWT_AUTH_PATH = 'gitlab_rails_jwt'
    OPENBAO_TOKEN_TTL = '15m'
    OPENBAO_TOKEN_MAX_TTL = '15m'
    OPENBAO_EXPIRATION_LEEWAY = 150
    OPENBAO_NOT_BEFORE_LEEWAY = 150
    OPENBAO_RECOVERY_SHARES_THRESHOLD = 1
    OPENBAO_CLOCK_SKEW_LEEWAY = 60
    OPENBAO_INLINE_AUTH_FAILED_HEADER = "X-Vault-Inline-Auth-Failed"
    OPENBAO_INLINE_AUTH_FAILED_VALUE = "true"

    ApiError = Class.new(StandardError)
    ConnectionError = Class.new(StandardError)
    AuthenticationError = Class.new(StandardError)
    ServiceUnavailableError = Class.new(StandardError)

    Configuration = Struct.new(:host, :base_path)

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration)
    end

    def self.expected_server_version
      path = Rails.root.join(SERVER_VERSION_FILE)
      path.read.chomp
    end

    def initialize(
      jwt:, role: DEFAULT_JWT_ROLE, auth_namespace: "", auth_mount: GITLAB_JWT_AUTH_PATH,
      use_cel_auth: false, namespace: "")
      @jwt = jwt
      @role = role
      @auth_namespace = auth_namespace
      @auth_mount = auth_mount
      @use_cel_auth = use_cel_auth
      @namespace = namespace
    end

    def enable_namespace(path, metadata: nil)
      make_request(:post, "sys/namespaces/#{path}", {
        custom_metadata: metadata
      })
    end

    def disable_namespace(path)
      make_request(:delete, "sys/namespaces/#{path}")
    end

    def with_namespace(namespace)
      SecretsManagerClient.new(jwt: @jwt, role: @role, auth_namespace: @auth_namespace, auth_mount: @auth_mount,
        use_cel_auth: @use_cel_auth, namespace: namespace)
    end

    def with_auth_namespace(auth_namespace)
      SecretsManagerClient.new(jwt: @jwt, role: @role, auth_namespace: auth_namespace, auth_mount: @auth_mount,
        use_cel_auth: @use_cel_auth, namespace: @namespace)
    end

    def enable_auth_engine(mount_path, type, allow_existing: false)
      make_request(:post, "sys/auth/#{mount_path}", { type: type })
    rescue ApiError => e
      raise e unless allow_existing
      raise e unless e.message.include? "path is already in use"

      true
    end

    def disable_auth_engine(mount_path)
      make_request(:delete, "sys/auth/#{mount_path}")
    end

    def enable_secrets_engine(mount_path, type)
      make_request(:post, "sys/mounts/#{mount_path}", { type: type })
    end

    def disable_secrets_engine(mount_path)
      make_request(:delete, "sys/mounts/#{mount_path}")
    end

    def list_secrets(mount_path, secret_path)
      result = make_request(:list, "#{mount_path}/detailed-metadata/#{secret_path}", {}, allow_not_found_response: true)
      return [] unless result

      keys = result.dig("data", "keys")
      raise ApiError, "Unexpected OpenBao response: missing keys field" unless keys

      key_info = result.dig("data", "key_info")
      raise ApiError, "Unexpected OpenBao response: missing key_info field" unless key_info

      keys.filter_map do |key|
        metadata = key_info[key]
        next unless metadata

        secret_data = { "key" => key, "metadata" => metadata }

        if block_given?
          yield(secret_data)
        else
          secret_data
        end
      end
    end

    def count_secrets(mount_path, secret_path, limit: nil)
      params = {}
      params[:limit] = limit unless limit.nil?

      result = make_request(:list, "#{mount_path}/metadata/#{secret_path}", params, allow_not_found_response: true)
      return 0 unless result

      keys = result.dig("data", "keys")
      raise ApiError, "Unexpected OpenBao response: missing keys field" unless keys

      keys.size
    end

    def list_policies(type: nil)
      subdir = "/#{type}" if type
      result = make_request(:list, "sys/policies/detailed/acl#{subdir}", {}, allow_not_found_response: true)
      return [] unless result

      key_info = result["data"]["key_info"] || {}

      key_info.filter_map do |key, raw_metadata|
        # Filter out system policies ('default' and 'root') that should not be exposed to users.
        next if (key == "root") || (key == "default")

        metadata = parse_policy_metadata(key, raw_metadata)
        next unless metadata

        policy_data = { "key" => key, "metadata" => metadata }
        if block_given?
          yield(policy_data)
        else
          policy_data
        end
      end
    end

    def list_project_policies(project_id:, type: nil, &block)
      subdir = "/#{type}" if type
      subtype = "project_#{project_id}#{subdir}"
      list_policies(type: subtype, &block)
    end

    def read_secret_metadata(mount_path, secret_path)
      result = make_request(:get, "#{mount_path}/metadata/#{secret_path}", {}, allow_not_found_response: true)
      return unless result

      result["data"]
    end

    def update_kv_secret_metadata(mount_path, secret_path, custom_metadata, metadata_cas: nil)
      payload = { custom_metadata: custom_metadata }
      payload[:metadata_cas] = metadata_cas if metadata_cas

      make_request(
        :post,
        "#{mount_path}/metadata/#{secret_path}",
        payload
      )
    end

    def update_kv_secret(mount_path, secret_path, value, cas: nil)
      options = { cas: cas } if cas

      make_request(
        :post,
        "#{mount_path}/data/#{secret_path}",
        {
          data: { KV_VALUE_FIELD => value },
          options: options
        }
      )
    end

    def delete_kv_secret(mount_path, secret_path)
      make_request(:delete, "#{mount_path}/metadata/#{secret_path}")
    end

    def configure_jwt(mount_path, server_url, jwk_signer)
      config = {
        bound_issuer: server_url
      }

      if Rails.env.test?
        jwk_key = OpenSSL::PKey::RSA.new(jwk_signer)
        jwk_verifier = jwk_key.public_key.to_s
        config[:jwt_validation_pubkeys] = jwk_verifier
      else
        config[:oidc_discovery_url] = server_url
      end

      make_request(:post, "auth/#{mount_path}/config", config)
    end

    def update_gitlab_rails_jwt_role(openbao_url:)
      role_data = {
        role_type: "jwt",
        bound_audiences: openbao_url
      }
      url = "auth/gitlab_rails_jwt/role/app"
      make_request(:post, url, role_data)
    end

    def update_jwt_role(mount_path, role_name, **role_data)
      ttl_values = {
        token_ttl: OPENBAO_TOKEN_TTL,
        token_max_ttl: OPENBAO_TOKEN_MAX_TTL
      }

      update_jwt_role_payload = ttl_values.merge(role_data)
      url = "auth/#{mount_path}/role/#{role_name}"
      make_request(:post, url, update_jwt_role_payload)
    end

    def update_jwt_cel_role(mount_path, role_name, **role_data)
      payload = {
        name: role_name,
        expiration_leeway: OPENBAO_EXPIRATION_LEEWAY,
        not_before_leeway: OPENBAO_NOT_BEFORE_LEEWAY,
        clock_skew_leeway: OPENBAO_CLOCK_SKEW_LEEWAY
      }
      update_jwt_cel_role_payload = payload.merge(role_data)

      make_request(:post, "auth/#{mount_path}/cel/role/#{role_name}", update_jwt_cel_role_payload)
    end

    def read_jwt_role(mount_path, role_name)
      url = "auth/#{mount_path}/role/#{role_name}"
      body = make_request(:get, url)
      body["data"] if body
    end

    def read_jwt_cel_role(mount_path, role_name)
      url = "auth/#{mount_path}/cel/role/#{role_name}"
      body = make_request(:get, url)
      body["data"] if body
    end

    def delete_jwt_role(mount_path, role_name)
      url = "auth/#{mount_path}/role/#{role_name}"
      make_request(:delete, url)
    end

    def delete_jwt_cel_role(mount_path, role_name)
      url = "auth/#{mount_path}/cel/role/#{role_name}"
      make_request(:delete, url)
    end

    def get_policy(name)
      policy = read_raw_policy name
      return AclPolicy.new(name) if policy.nil?

      parsed = Gitlab::Json.parse(policy["policy"])
      AclPolicy.build_from_hash(name, parsed)
    end

    def set_policy(policy)
      save_raw_policy(policy.name, policy.to_openbao_attributes.to_json)
    end

    def delete_policy(name)
      make_request(
        :delete,
        "sys/policies/acl/#{name}",
        {},
        allow_not_found_response: true
      )
    end

    def init_rotate_recovery
      recovery_values = {
        secret_shares: OPENBAO_RECOVERY_SHARES_THRESHOLD,
        secret_threshold: OPENBAO_RECOVERY_SHARES_THRESHOLD
      }

      make_request(:post, rotate_recovery_url, recovery_values)
    end

    def cancel_rotate_recovery
      make_request(:delete, rotate_recovery_url)
    end

    # Resolves the current user's effective capabilities on the given paths.
    #
    # This is the one method that deliberately does NOT use inline auth. Inline
    # auth makes OpenBao mint an ephemeral, request-scoped token that is never
    # written to the token store. `sys/capabilities-self` resolves the caller's
    # policies by looking its token up in the store, so an inline-auth token is
    # rejected with "invalid token" (the same failure as `auth/token/lookup-self`).
    # Data-plane reads/writes work over inline auth because they evaluate ACL
    # inline and never look the token up; capabilities-self cannot.
    #
    # So we log in explicitly (this client already holds the jwt) to mint a real,
    # persisted token, call capabilities-self with it via X-Vault-Token, then
    # revoke it. The user_jwt CEL login caps the minted token at a short TTL
    # (~5 min default), so a leaked token expires quickly on its own; we revoke
    # per call to release it immediately rather than let it linger for the TTL.
    def capabilities_self(paths:)
      token = login_with_jwt
      send_token_request(token_connection(token), :post, namespaced_url("sys/capabilities-self"), { paths: paths })
    ensure
      revoke_self(token) if token
    end

    def cel_login_jwt(mount_path:, role:, jwt:)
      url = "auth/#{mount_path}/cel/login"
      body = { role: role, jwt: jwt }
      make_request(:post, url, body)
    end

    def inline_auth_path
      ns = ""
      ns = "#{auth_namespace}/" unless auth_namespace.empty?

      if use_cel_auth
        "#{ns}auth/#{auth_mount}/cel/login"
      else
        "#{ns}auth/#{auth_mount}/login"
      end
    end

    def server_available?
      # Force 200 for standby/sealed/uninitialized so the body reaches our checks instead of Faraday's raise_error.
      response = make_request(:get, "sys/health", { standbyok: true, sealedcode: 200, uninitcode: 200 })
      initialized = response.fetch('initialized', false)
      sealed = response.fetch('sealed', true)

      return true if initialized && !sealed

      Gitlab::AppLogger.warn(
        message: '[OpenBao] health check returned unhealthy',
        reason: initialized ? 'sealed' : 'not_initialized',
        initialized: initialized,
        sealed: sealed,
        standby: response['standby']
      )
      false
    rescue ConnectionError, ApiError, ServiceUnavailableError => e
      Gitlab::AppLogger.warn(
        message: '[OpenBao] health check failed',
        reason: e.class.name,
        error: e.message
      )
      false
    end

    private

    attr_reader :jwt, :role, :auth_namespace, :auth_mount, :use_cel_auth, :namespace

    # save_raw_policy and read_raw_policy handle raw (direct API responses)
    # and the get_policy/set_policy forms should be preferred as they return
    # typed (JSON-able) policies. The risk with these endpoints is that
    # direct usage with HCL will result in non-JSON-parseable policies that
    # cannot be easily modified by Rails.
    def save_raw_policy(name, value)
      make_request(
        :post,
        "sys/policies/acl/#{name}",
        {
          policy: value
        }
      )
    end

    def read_raw_policy(name)
      body = make_request(:get, "sys/policies/acl/#{name}", {}, allow_not_found_response: true)
      body["data"] if body
    end

    def parse_policy_metadata(name, raw_metadata)
      policy_json = raw_metadata.fetch("policy", nil)
      return AclPolicy.new(name) if policy_json.nil?

      parsed = Gitlab::Json.parse(policy_json)
      AclPolicy.build_from_hash(name, parsed)
    end

    # Explicit (non-inline) login that returns a real, persisted token.
    # See #capabilities_self for why inline auth cannot be used here.
    def login_with_jwt
      body = send_token_request(token_connection, :post, inline_auth_path, { role: role, jwt: jwt })
      body&.dig("auth", "client_token")
    end

    def revoke_self(token)
      send_token_request(token_connection(token), :post, namespaced_url("auth/token/revoke-self"))
    rescue ApiError, ConnectionError, ServiceUnavailableError
      # Best-effort cleanup. If revocation fails the token lives until its TTL
      # expires it; the user_jwt CEL login caps that at a short TTL (~5 min
      # default), so a leaked token is bounded rather than left for OpenBao's
      # long default.
      nil
    end

    # A connection without inline-auth headers, optionally authenticated with an
    # explicit token. Used only by the capabilities-self flow.
    def token_connection(token = nil)
      Faraday.new(url: URI.join(configuration.host, configuration.base_path)) do |f|
        f.request :json
        f.response :json
        f.response :raise_error, allowed_statuses: [404]

        f.headers['X-Vault-Token'] = token if token
      end
    end

    def send_token_request(conn, method, path, params = {})
      response = conn.public_send(method, path, params) # rubocop:disable GitlabSecurity/PublicSend -- method is an internal symbol (:post)
      body = response.body
      raise ApiError, parsed_error_message(response) if body && body["errors"]&.any?

      body
    rescue ::Faraday::ClientError => error
      raise ApiError, parsed_error_message(error.response)
    rescue ::Faraday::ServerError => error
      raise ServiceUnavailableError,
        parsed_error_message(error.response, default_error_message: "OpenBao service unavailable")
    rescue ::Faraday::Error => e
      raise ConnectionError, e.message
    end

    def connection
      Faraday.new(url: URI.join(configuration.host, configuration.base_path)) do |f|
        f.request :json
        f.response :json
        f.response :raise_error, allowed_statuses: [404]

        f.headers['X-Vault-Inline-Auth-Path'] = inline_auth_path

        f.headers['X-Vault-Inline-Auth-Parameter-token'] =
          Base64.urlsafe_encode64({ key: "jwt", value: jwt }.to_json, padding: false)

        if role.present?
          f.headers['X-Vault-Inline-Auth-Parameter-role'] =
            Base64.urlsafe_encode64({ key: "role", value: role }.to_json, padding: false)
        end
      end
    end
    strong_memoize_attr :connection

    def namespaced_url(path)
      if namespace.empty?
        path
      else
        "#{namespace}/#{path}"
      end
    end

    def make_request(method, url, params = {}, allow_not_found_response: false)
      path = namespaced_url(url)
      response = case method
                 when :get
                   connection.get(path, params)
                 when :list
                   connection.get(path, params.merge(list: true))
                 when :scan
                   connection.get(path, params.merge(scan: true))
                 when :delete
                   connection.delete(path, params)
                 else
                   connection.post(path, params)
                 end

      body = response.body

      # to handle the case when inline auth error with HTTP 404 error code and error is NOT raised
      handle_authentication_error!(response)

      raise ApiError, parsed_error_message(response) if body && body["errors"]&.any?

      handle_openbao_warnings!(body, endpoint: path, namespace: namespace, method: method)

      if response.status == 404
        raise ApiError, 'not found' unless allow_not_found_response

        return
      end

      body
    rescue ::Faraday::ClientError => error
      handle_authentication_error!(error.response)

      raise ApiError, parsed_error_message(error.response)
    rescue ::Faraday::ServerError => error
      raise ServiceUnavailableError,
        parsed_error_message(error.response, default_error_message: "OpenBao service unavailable")
    rescue ::Faraday::Error => e
      raise ConnectionError, e.message
    end

    def authentication_error?(response)
      # for ::Faraday::Error responses from raise_error middleware
      headers = response[:headers] if response.is_a?(Hash)

      # for Faraday::Response object when NO errors are raised
      headers = response.headers if response.respond_to?(:headers)

      headers && headers.key?(OPENBAO_INLINE_AUTH_FAILED_HEADER) &&
        headers[OPENBAO_INLINE_AUTH_FAILED_HEADER] == OPENBAO_INLINE_AUTH_FAILED_VALUE
    end

    def handle_authentication_error!(response)
      return unless authentication_error?(response)

      raise AuthenticationError,
        parsed_error_message(response, default_error_message: "Failed to authenticate with OpenBao")
    end

    def get_response_body_from_response(response)
      return response[:body] if response.is_a?(Hash) # for ::Faraday::Error responses from raise_error middleware

      response.body # for Faraday::Response object when NO errors are raised
    end

    def configuration
      self.class.configuration
    end

    def rotate_recovery_url
      "sys/rotate/recovery/init"
    end

    def parsed_error_message(response, default_error_message: "OpenBao API request failed")
      response_body = get_response_body_from_response(response)
      return default_error_message unless response_body.present?

      errors = if response_body.is_a?(Hash) # for body of a Faraday::Response object when NO errors are raised
                 response_body["errors"]
               elsif response_body.is_a?(String) # for a JSON String response_body of ::Faraday::Error from raise_error
                 parsed = Gitlab::Json.parse(response_body)
                 parsed["errors"] if parsed.is_a?(Hash)
               end

      errors_array = Array(errors)
      errors_array.any? ? errors_array.to_sentence : default_error_message
    rescue Gitlab::Json.parser_error
      default_error_message
    end
  end
end
