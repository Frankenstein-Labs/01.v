# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'

module ArtifactRegistry
  class Client
    RETRY_EXCEPTIONS = [Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS, Faraday::ConnectionFailed].flatten.freeze
    RETRY_OPTIONS = {
      max: 1,
      interval: 0,
      exceptions: RETRY_EXCEPTIONS
    }.freeze

    ERROR_CALLBACK_OPTIONS = {
      callback: ->(env, exception) do
        Gitlab::ErrorTracking.log_exception(
          exception,
          class: name,
          url: env[:url]
        )
      end
    }.freeze

    API_VERSION = 'api/v1'

    MAX_ERROR_BODY_SNIPPET = 200

    PAGINATION_RELS = %i[next prev].freeze

    PACKAGE_FORMATS = %w[maven npm].freeze
    IMAGE_FORMATS = %w[docker oci].freeze

    # AR's error envelope is exhaustive, so a JSON error body without one came from an intermediary such as an
    # auth proxy. Only conventional human-readable fields are surfaced; anything else may carry its credentials.
    ERROR_SNIPPET_KEYS = %w[detail message title].freeze

    REDACTED_VALUE = '[REDACTED]'
    BEARER_CREDENTIAL_PATTERN = /(bearer\s+)\S+/i
    JWT_PATTERN = /[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}/

    # Separates an omitted field from an explicit nil, which the contract sends as JSON null.
    NOT_PROVIDED = Object.new.freeze

    class Error < StandardError
      attr_reader :status, :request_id

      def initialize(message = nil, status: nil, request_id: nil)
        super(message)
        @status = status
        @request_id = request_id
      end
    end

    AuthorizationError = Class.new(Error)
    UnavailableError = Class.new(Error)

    class ApiError < Error
      attr_reader :code

      def initialize(message = nil, status: nil, code: nil, request_id: nil)
        super(message, status: status, request_id: request_id)
        @code = code
      end
    end

    def initialize(current_user:, base_url: nil, token_exchange: nil)
      # Read the key rather than call it: the setting is only defaulted in development and test, and
      # the reader raises Gitlab::Configs::MissingConfig on an instance that never set it, which no
      # caller rescues. Nil instead lands on the guard below.
      base_url = base_url.presence || Gitlab.config.artifact_registry['api_url']

      raise ArgumentError, 'base_url is required' if base_url.blank?
      raise ArgumentError, 'base_url must be an http(s) URL' unless base_url.to_s.match?(%r{\Ahttps?://})

      @current_user = current_user
      @base_url = base_url
      @token_exchange = token_exchange || TokenExchange.new
    end

    def repository(slug:, name:)
      guard_segments!(slug: slug, name: name)

      nil_on_missing(slug: slug) do
        response = request(:get, repository_path(slug, name), slug: slug)

        Repository.new(success_body(response, slug: slug, expected: Hash))
      end
    end

    def repositories(slug:, format: nil, kind: nil, sort: nil, order: nil, limit: nil, cursor: nil)
      guard_segments!(slug: slug)

      query = { format: format, kind: kind, sort: sort, order: order, limit: limit, cursor: cursor }.compact

      # Logged because an unreachable namespace can equally mean the slug this caller holds has
      # drifted from Artifact Registry's.
      nil_on_missing(slug: slug, log: true) do
        response = request(:get, repositories_path(slug), slug: slug, query: query)
        attributes_list = success_body(response, slug: slug, expected: Array)
        raise_unexpected_success(response, slug: slug) unless attributes_list.all?(Hash)

        cursors = link_cursors(response, slug: slug)

        Page.new(
          nodes: attributes_list.map { |attributes| Repository.new(attributes) },
          next_cursor: cursors[:next],
          prev_cursor: cursors[:prev]
        )
      end
    end

    def packages(slug:, repository_name:, format:, limit: nil, cursor: nil)
      guard_format!(format, PACKAGE_FORMATS)

      artifact_page(slug: slug, repository_name: repository_name, format: format, collection: 'packages',
        row_class: package_class(format), limit: limit, cursor: cursor)
    end

    def images(slug:, repository_name:, format:, limit: nil, cursor: nil)
      guard_format!(format, IMAGE_FORMATS)

      artifact_page(slug: slug, repository_name: repository_name, format: format, collection: 'images',
        row_class: Image, limit: limit, cursor: cursor)
    end

    def create_repository(slug:, name:, format:, kind: nil, visibility: nil, description: nil)
      guard_segments!(slug: slug, name: name)
      guard_present!(format: format)

      body = { name: name, format: format, kind: kind, visibility: visibility, description: description }.compact
      response = request(:post, repositories_path(slug), slug: slug, body: body)

      Repository.new(success_body(response, slug: slug, expected: Hash))
    end

    def update_repository(slug:, name:, visibility: NOT_PROVIDED, description: NOT_PROVIDED)
      guard_segments!(slug: slug, name: name)

      body = provided_fields(visibility: visibility, description: description)
      raise ArgumentError, 'at least one mutable field is required' if body.empty?

      response = request(:patch, repository_path(slug, name), slug: slug, body: body)

      Repository.new(success_body(response, slug: slug, expected: Hash))
    end

    def delete_repository(slug:, name:)
      guard_segments!(slug: slug, name: name)

      request(:delete, repository_path(slug, name), slug: slug)

      true
    rescue ApiError => e
      raise unless e.status == 404 && e.code == 'not_found'

      true
    end

    private

    def guard_format!(format, allowed)
      raise ArgumentError, "format must be one of: #{allowed.join(', ')}" if allowed.exclude?(format)
    end

    # Second line of defense behind guard_format!, so a format added to PACKAGE_FORMATS without a
    # class here raises the name of the miss, rather than reaching `row_class.new` as nil.
    def package_class(format)
      case format
      when 'maven' then MavenPackage
      when 'npm' then NpmPackage
      else raise ArgumentError, "format must be one of: #{PACKAGE_FORMATS.join(', ')}"
      end
    end

    # Reports a 404 as an absence rather than raising. Pass log: true where an unresolvable path is
    # not an ordinary outcome for the caller, so the drift behind it stays diagnosable.
    def nil_on_missing(slug:, log: false)
      yield
    rescue ApiError => e
      raise unless e.status == 404

      log_error(e, slug: slug) if log
      nil
    end

    def artifact_page(slug:, repository_name:, format:, collection:, row_class:, limit:, cursor:)
      guard_segments!(slug: slug, repository_name: repository_name)

      query = { limit: limit, cursor: cursor }.compact
      path = artifacts_path(slug, repository_name, format, collection)

      nil_on_missing(slug: slug, log: true) do
        response = request(:get, path, slug: slug, query: query)
        attributes_list = success_body(response, slug: slug, expected: Array)
        raise_unexpected_success(response, slug: slug) unless attributes_list.all?(Hash)

        cursors = link_cursors(response, slug: slug)

        Page.new(
          nodes: attributes_list.map { |attributes| row_class.new(attributes) },
          next_cursor: cursors[:next],
          prev_cursor: cursors[:prev]
        )
      end
    end

    def request(http_method, path, slug:, query: nil, body: nil)
      context = request_context(slug)
      token = @token_exchange.token_for(@current_user, slug)
      raise_missing_credential if token.blank?

      response = connection.run_request(http_method, path, body, nil) do |req|
        req.params.update(query) if query.present?
        req.headers['Authorization'] = "Bearer #{token}"

        correlation_id = Labkit::Correlation::CorrelationId.current_id
        req.headers['X-Request-Id'] = correlation_id if correlation_id
      end

      handle_response(response, context)
    rescue ::Faraday::ParsingError => e
      status = e.response_status
      raise ApiError.new(status: 404) if status == 404

      message = 'Artifact Registry returned an unreadable response'
      raise AuthorizationError.new(message, status: status) if [401, 403].include?(status)

      raise_unavailable(message, status: status, context: context)
    rescue ::Faraday::SSLError => e
      raise UnavailableError, "Artifact Registry TLS connection failed: #{e.message}"
    rescue ::Faraday::Error
      raise UnavailableError, 'Artifact Registry request failed'
    end

    def handle_response(response, context)
      status = response.status

      return response if (200..299).cover?(status)

      raise_error(status, response, context)
    end

    def success_body(response, slug:, expected:)
      body = response.body
      return body if body.is_a?(expected)

      raise_unexpected_success(response, slug: slug)
    end

    def raise_unexpected_success(response, slug:)
      raise_unavailable(
        'Artifact Registry returned an unexpected success response',
        status: response.status,
        context: request_context(slug).merge(body_class: response.body.class.name)
      )
    end

    def request_context(slug)
      { url: @base_url, slug: slug }
    end

    def link_cursors(response, slug:)
      header = response.headers['Link']
      links = Gitlab::Utils::LinkHeaderParser.new(header).parse

      # Reading the header rather than each URI keeps the last page quiet: it still carries rel="prev".
      if header.present? && !links.keys.intersect?(PAGINATION_RELS)
        log_error(Error.new('Artifact Registry Link header yielded no usable rels'), slug: slug)
      end

      PAGINATION_RELS.index_with { |direction| link_cursor(links.dig(direction, :uri), direction, slug: slug) }
    rescue URI::InvalidURIError => e
      log_error(e, slug: slug)
      PAGINATION_RELS.index_with(nil)
    end

    def link_cursor(uri, direction, slug:)
      return unless uri

      cursor = Rack::Utils.parse_query(uri.query)['cursor']
      return cursor if cursor.present?

      log_error(Error.new("Artifact Registry #{direction} link carries no cursor"), slug: slug)
      nil
    end

    def log_error(error, slug:)
      Gitlab::ErrorTracking.log_exception(error, request_context(slug))
    end

    def raise_missing_credential
      raise AuthorizationError, 'No Artifact Registry credential was obtained for the current user'
    end

    def raise_unavailable(message, status: nil, context: {})
      error = UnavailableError.new(message, status: status)
      Gitlab::ErrorTracking.log_exception(error, context.merge(status: status).compact)
      raise error
    end

    def raise_error(status, response, context)
      envelope = error_envelope(response)
      message = envelope[:message]
      request_id = envelope[:request_id]

      case status
      when 401, 403
        raise AuthorizationError.new(message, status: status, request_id: request_id)
      when 429, 500..599
        error = UnavailableError.new(message, status: status, request_id: request_id)
        Gitlab::ErrorTracking.log_exception(
          error,
          context.merge(status: status, code: envelope[:code], request_id: request_id).compact
        )
        raise error
      else
        raise ApiError.new(message, status: status, code: envelope[:code], request_id: request_id)
      end
    end

    def error_envelope(response)
      body = response.body
      error = body['error'] if body.is_a?(Hash)

      return { code: nil, message: redacted_snippet(error), request_id: nil } if error.is_a?(String)
      return error_snippet_envelope(body) unless error.is_a?(Hash)

      {
        code: redacted_snippet(error['code'].to_s),
        message: redacted_snippet(error['message'].to_s),
        request_id: redacted_snippet(error['request_id'].to_s)
      }
    end

    def error_snippet_envelope(body)
      snippet =
        case body
        when String then redacted_snippet(body)
        when Hash then redacted_snippet(body.values_at(*ERROR_SNIPPET_KEYS).grep(String).join(' '))
        end

      { code: nil, message: snippet, request_id: nil }
    end

    def redacted_snippet(body)
      body
        .gsub(BEARER_CREDENTIAL_PATTERN, "\\1#{REDACTED_VALUE}")
        .gsub(JWT_PATTERN, REDACTED_VALUE)
        .strip
        .presence
        &.truncate(MAX_ERROR_BODY_SNIPPET)
    end

    def repositories_path(slug)
      "#{API_VERSION}/#{encode_segment(slug)}/repositories"
    end

    def repository_path(slug, name)
      "#{repositories_path(slug)}/#{encode_segment(name)}"
    end

    def artifacts_path(slug, repository_name, format, collection)
      "#{repository_path(slug, repository_name)}/#{encode_segment(format)}/#{collection}"
    end

    def encode_segment(value)
      ERB::Util.url_encode(value.to_s)
    end

    def provided_fields(**fields)
      fields.reject { |_field, value| value.equal?(NOT_PROVIDED) }
    end

    def guard_present!(**fields)
      fields.each do |field, value|
        raise ArgumentError, "#{field} is required" if value.blank?
      end
    end

    def guard_segments!(**segments)
      guard_present!(**segments)

      segments.each do |segment, value|
        raise ArgumentError, "#{segment} must not be a bare '.' or '..' segment" if dot_segment?(value)
      end
    end

    def dot_segment?(value)
      value == '.' || value == '..'
    end

    def connection
      @connection ||= Faraday.new(@base_url, headers: { user_agent: "GitLab/#{Gitlab::VERSION}" },
        request: Gitlab::HTTP::DEFAULT_TIMEOUT_OPTIONS) do |conn|
        conn.request :json
        conn.response :json, content_type: 'application/json'
        conn.request :retry, RETRY_OPTIONS
        conn.request :gitlab_error_callback, ERROR_CALLBACK_OPTIONS
        conn.adapter :net_http
      end
    end
  end
end
