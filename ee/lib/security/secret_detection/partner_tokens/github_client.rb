# frozen_string_literal: true

module Security
  module SecretDetection
    module PartnerTokens
      # Verifier for GitHub personal access tokens (classic).
      #
      # Approach: call GitHub's `GET /user` endpoint with the token in the
      # Authorization header.
      #   - 200 => token is active
      #   - 401 => token is inactive (revoked/expired/invalid)
      # Anything ambiguous (rate limit, 5xx, unexpected code) is surfaced as
      # unknown or raised so the token is never wrongly reported inactive.
      #
      # Ref: https://docs.github.com/en/rest/users/users#get-the-authenticated-user
      class GithubClient < BaseClient
        API_ENDPOINT = 'https://api.github.com/user'

        # GitHub classic personal access tokens: ghp_ followed by 36 base62 chars.
        # Ref: https://gitlab.com/gitlab-org/security-products/secret-detection/secret-detection-rules
        TOKEN_PATTERN = /\Aghp_[0-9a-zA-Z]{36}\z/

        private

        def valid_format?(token_value)
          return false unless token_value

          token_value.match?(TOKEN_PATTERN)
        end

        def verify_partner_token(token_value)
          response = make_github_request(token_value)
          analyze_github_response(response)
        end

        def make_github_request(token_value)
          headers = {
            'Authorization' => "Bearer #{token_value}",
            'Accept' => 'application/vnd.github+json',
            'X-GitHub-Api-Version' => '2022-11-28'
          }

          make_request(API_ENDPOINT, method: :get, headers: headers)
        end

        def analyze_github_response(response)
          case response.code.to_i
          when 200
            token_response(:active)
          when 401
            # Bad credentials: token is revoked, expired, or never valid.
            token_response(:inactive)
          when 403, 429
            # Secondary rate limit / abuse detection.
            raise RateLimitError, "GitHub API rate limited: #{response.code}"
          when 500, 502, 503, 504
            raise NetworkError, "GitHub service error: #{response.code}"
          else
            # Never downgrade an ambiguous answer to inactive.
            token_response(:unknown)
          end
        end
      end
    end
  end
end
