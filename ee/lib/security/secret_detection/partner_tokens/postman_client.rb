# frozen_string_literal: true

module Security
  module SecretDetection
    module PartnerTokens
      class PostmanClient < BaseClient
        API_ENDPOINT = 'https://api.getpostman.com/me'

        private

        def valid_format?(token_value)
          # Match Postman API key pattern based on secret detection rules
          # Postman API keys are typically 64 character hexadecimal strings
          # Pattern: PMAK-[a-f0-9]{24}-[a-f0-9]{34}
          return false unless token_value

          postman_api_key_pattern = /\APMAK-[a-f0-9]{24}-[a-f0-9]{34}\z/

          token_value.match?(postman_api_key_pattern)
        end

        # Postman /me endpoint approach:
        # Send API key via X-API-Key header to validate its status
        # - Valid token: 200 response with user details
        # - Invalid/revoked token: 401 response
        def verify_partner_token(token_value)
          response = make_postman_request(token_value)
          analyze_postman_response(response)
        end

        def make_postman_request(token_value)
          headers = {
            'X-API-Key' => token_value,
            'Accept' => 'application/json'
          }

          make_request(API_ENDPOINT, method: :get, headers: headers)
        end

        def analyze_postman_response(response)
          case response.code.to_i
          when 200
            token_response(:active)

          when 401
            # Invalid or revoked API key
            token_response(:inactive)

          when 429
            # Postman rate limiting - strict 3 req/s limit
            raise RateLimitError, "Postman API rate limited: #{response.code}"

          when 500, 502, 503, 504
            # Postman service errors - should retry
            raise NetworkError, "Postman service error: #{response.code}"

          else
            # Other unexpected responses
            raise ResponseError, "Unexpected service error with code: #{response.code}"
          end
        end
      end
    end
  end
end
