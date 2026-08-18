# frozen_string_literal: true

module Security
  module SecretDetection
    module PartnerTokens
      # Verifier for OpenAI project API keys.
      #
      # Approach: call `GET /v1/models` with the key as a Bearer token.
      #   - 200 => active
      #   - 401 with code invalid_api_key => inactive (the key is not correct)
      #   - any other 401 => unknown, see analyze_unauthorized below
      # Rate limits and service errors are raised; everything else is unknown.
      #
      # Ref: https://platform.openai.com/docs/api-reference/models/list
      class OpenaiClient < BaseClient
        API_ENDPOINT = 'https://api.openai.com/v1/models'

        # The only 401 error code OpenAI documents as meaning the key itself is
        # not valid. Ref: https://developers.openai.com/api/docs/guides/error-codes
        INVALID_KEY_CODE = 'invalid_api_key'

        # OpenAI project keys: sk-proj- followed by a long base62/-/_ body.
        # The bounds mirror the OpenAiProjectKey detection rule exactly, so the
        # verifier only attempts strings the scanner would have flagged.
        # Ref: https://gitlab.com/gitlab-org/security-products/secret-detection/secret-detection-rules
        TOKEN_PATTERN = /\Ask-proj-[a-zA-Z0-9_-]{40,190}\z/

        private

        def valid_format?(token_value)
          return false unless token_value

          token_value.match?(TOKEN_PATTERN)
        end

        def verify_partner_token(token_value)
          response = make_openai_request(token_value)
          analyze_openai_response(response)
        end

        def make_openai_request(token_value)
          headers = {
            'Authorization' => "Bearer #{token_value}",
            'Accept' => 'application/json'
          }

          make_request(API_ENDPOINT, method: :get, headers: headers)
        end

        def analyze_openai_response(response)
          case response.code.to_i
          when 200
            token_response(:active)
          when 401
            analyze_unauthorized(response)
          when 429
            raise RateLimitError, "OpenAI API rate limited: #{response.code}"
          when 500, 502, 503, 504
            raise NetworkError, "OpenAI service error: #{response.code}"
          else
            token_response(:unknown)
          end
        end

        # OpenAI documents four causes of 401 and only one of them means the
        # key is dead: "Incorrect API key provided", which carries the
        # invalid_api_key code. The others describe a live key this request
        # cannot use - an organization mismatch, an account that belongs to no
        # organization, and a request IP outside the organization's allowlist.
        # Treating those as revoked would report a live credential as dead.
        def analyze_unauthorized(response)
          error = parse_json_response(response)['error'].to_h

          return token_response(:inactive) if error['code'] == INVALID_KEY_CODE

          token_response(:unknown)
        end
      end
    end
  end
end
