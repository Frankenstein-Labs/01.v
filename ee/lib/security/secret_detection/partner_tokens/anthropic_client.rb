# frozen_string_literal: true

module Security
  module SecretDetection
    module PartnerTokens
      # Verifier for Anthropic API keys.
      #
      # Approach: call `GET /v1/models`, which lists model metadata, with the
      # key in the x-api-key header:
      #   - 200 => active (the key authenticated)
      #   - 401 => inactive (authentication_error: bad/revoked key)
      #
      # Ref: https://platform.claude.com/docs/en/api/models-list
      class AnthropicClient < BaseClient
        API_ENDPOINT = 'https://api.anthropic.com/v1/models'
        API_VERSION = '2023-06-01'

        # Anthropic keys: sk-ant-<section>-<body> with base62/-/_ chars.
        # The pattern mirrors the anthropic_key detection rule exactly, so the
        # verifier only attempts strings the scanner would have flagged.
        # Ref: https://gitlab.com/gitlab-org/security-products/secret-detection/secret-detection-rules
        TOKEN_PATTERN = /\Ask-ant-[a-z]{3}\d{2}-[0-9A-Za-z_-]{94}[0-9A-Za-z_]\z/

        private

        def valid_format?(token_value)
          return false unless token_value

          token_value.match?(TOKEN_PATTERN)
        end

        def verify_partner_token(token_value)
          response = make_anthropic_request(token_value)
          analyze_anthropic_response(response)
        end

        def make_anthropic_request(token_value)
          headers = {
            'x-api-key' => token_value,
            'anthropic-version' => API_VERSION
          }

          make_request(API_ENDPOINT, method: :get, headers: headers)
        end

        def analyze_anthropic_response(response)
          case response.code.to_i
          when 200
            token_response(:active)
          when 401
            # authentication_error: key is invalid/revoked.
            token_response(:inactive)
          when 429
            raise RateLimitError, "Anthropic API rate limited: #{response.code}"
          when 500, 502, 503, 504, 529
            raise NetworkError, "Anthropic service error: #{response.code}"
          else
            token_response(:unknown)
          end
        end
      end
    end
  end
end
