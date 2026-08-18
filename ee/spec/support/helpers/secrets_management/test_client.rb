# frozen_string_literal: true

module SecretsManagement
  class TestClient < SecretsManagerClient
    attr_reader :jwt, :role, :auth_namespace, :auth_mount, :use_cel_auth, :namespace

    def read_secrets_engine_configuration(mount_path)
      make_request(:get, "sys/mounts/#{mount_path}")
    end

    def read_auth_engine_configuration(mount_path)
      make_request(:get, "sys/auth/#{mount_path}")
    end

    def read_jwt_auth_config(mount_path)
      make_request(:get, "auth/#{mount_path}/config", {}, allow_not_found_response: true)
    end

    def with_namespace(namespace)
      TestClient.new(jwt: @jwt, role: @role, auth_namespace: @auth_namespace, auth_mount: @auth_mount,
        use_cel_auth: @use_cel_auth, namespace: namespace)
    end

    def with_auth_namespace(auth_namespace)
      TestClient.new(jwt: @jwt, role: @role, auth_namespace: auth_namespace, auth_mount: @auth_mount,
        use_cel_auth: @use_cel_auth, namespace: @namespace)
    end

    def each_secrets_engine
      body = make_request(:get, "sys/mounts", {}, allow_not_found_response: true)
      return unless body

      body["data"].each do |path, info|
        yield(path, info)
      end
    end

    def each_auth_engine
      body = make_request(:get, "sys/auth", {}, allow_not_found_response: true)
      return unless body

      body["data"].each do |path, info|
        yield(path, info)
      end
    end

    def each_acl_policy
      body = make_request(:list, "sys/policies/acl", {}, allow_not_found_response: true)
      return unless body

      body["data"]["keys"].each do |policy|
        yield(policy)
      end
    end

    def each_namespace
      body = make_request(:scan, "sys/namespaces", {}, allow_not_found_response: true)
      return unless body
      return unless body["data"].key?("keys")
      return if body["data"]["keys"].nil?

      # Iterate depth-first; do not immediately yield the namespace path
      # but instead sort by most nested.
      ordered = body["data"]["keys"].map do |path|
        path
      end

      ordered.sort! { |a, b| b.count('/') <=> a.count('/') }
      ordered.each do |path|
        yield(path)
      end
    end

    def read_namespace(namespace_path)
      make_request(:get, "sys/namespaces/#{namespace_path}")
    end

    def read_kv_secret_value(mount_path, secret_path, version: nil)
      body = make_request(
        :get,
        "#{mount_path}/data/#{secret_path}",
        {
          version: version
        },
        allow_not_found_response: true
      )

      return unless body

      body.dig("data", "data", KV_VALUE_FIELD)
    end

    def configuration
      SecretsManagerClient.configuration
    end

    def get_raw_policy(name)
      read_raw_policy(name)
    end

    def jwt_login
      response = make_request(:post, inline_auth_path_without_namespace, { jwt: jwt, role: role })
      { success: true, token: response.dig("auth", "client_token") }
    rescue AuthenticationError, ConnectionError, ApiError => e
      { success: false, error: e.message }
    end

    # This is because the make_request method always prefixes
    # the path with the namespace
    def inline_auth_path_without_namespace
      if use_cel_auth
        "auth/#{auth_mount}/cel/login"
      else
        "auth/#{auth_mount}/login"
      end
    end
  end
end
