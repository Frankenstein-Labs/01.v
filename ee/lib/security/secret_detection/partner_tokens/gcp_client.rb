# frozen_string_literal: true

module Security
  module SecretDetection
    module PartnerTokens
      class GcpClient < BaseClient
        TOKENINFO_ENDPOINT = 'https://oauth2.googleapis.com/tokeninfo'

        # GCP OAuth Access Token pattern: ya29.[0-9A-Za-z_-]{100,}
        # Ref: https://gitlab.com/gitlab-org/security-products/secret-detection/secret-detection-rules/-/blob/main/rules/mit/gcp/gcp.toml
        ACCESS_TOKEN_PATTERN = /\Aya29\.[0-9A-Za-z_-]{100,}\z/

        private

        def valid_format?(token_value)
          return false unless token_value

          # Only OAuth access tokens can be checked against the tokeninfo
          # endpoint. API keys and client secrets used to be accepted here,
          # but tokeninfo rejects them with a 400 whether or not they are
          # live, so live credentials were misreported as inactive. They
          # return unknown until we can verify them against a suitable
          # endpoint. See https://gitlab.com/gitlab-org/gitlab/-/work_items/588454.
          token_value.match?(ACCESS_TOKEN_PATTERN)
        end

        # GCP OAuth2 tokeninfo endpoint approach:
        # Send access token as query parameter to validate its status
        # - Valid token: 200 response with token details
        # - Invalid/expired token: 400/401 response
        def verify_partner_token(token_value)
          response = make_tokeninfo_request(token_value)
          analyze_gcp_response(response)
        end

        def make_tokeninfo_request(token_value)
          # URL encode the token value for query parameter
          encoded_token = CGI.escape(token_value)
          url = "#{TOKENINFO_ENDPOINT}?access_token=#{encoded_token}"

          make_request(url, method: :get)
        end

        def analyze_gcp_response(response)
          case response.code.to_i
          when 200
            token_response(:active)

          when 400, 401
            # Invalid or expired token
            token_response(:inactive)

          when 429
            # GCP rate limiting
            raise RateLimitError, "GCP tokeninfo rate limited: #{response.code}"

          when 500, 502, 503, 504
            # GCP service errors - should retry
            raise NetworkError, "GCP service error: #{response.code}"

          else
            # Other unexpected responses
            token_response(:unknown)
          end
        end
      end
    end
  end
end
