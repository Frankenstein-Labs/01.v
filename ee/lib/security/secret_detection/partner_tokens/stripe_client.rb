# frozen_string_literal: true

module Security
  module SecretDetection
    module PartnerTokens
      # Verifier for Stripe live secret keys.
      #
      # Approach: call `GET /v1/balance` with the key as HTTP Basic username.
      #   - 200 => active
      #   - 401 => inactive (invalid/revoked/expired key)
      # Stripe uniquely lets us integration-test the happy path too, because it
      # issues real *test-mode* keys (sk_test_...) whose balance endpoint
      # responds 200 without any side effects.
      #
      # Ref: https://docs.stripe.com/api/balance/balance_retrieve
      class StripeClient < BaseClient
        API_ENDPOINT = 'https://api.stripe.com/v1/balance'

        # Stripe live secret keys: sk_live_ + 99 base62 chars, mirroring the
        # StripeLiveSecretKey detection rule exactly.
        #
        # Stripe issues other credentials this verifier deliberately does not
        # claim: the 24-character StripeLiveShortSecretKey, restricted keys
        # (rk_live_), and publishable keys (pk_live_). Each is its own detection
        # rule, so under ADR-006 each needs its own verifier class rather than
        # a wider pattern here. Tracked in
        # https://gitlab.com/gitlab-org/gitlab/-/work_items/588601.
        # Ref: https://gitlab.com/gitlab-org/security-products/secret-detection/secret-detection-rules
        TOKEN_PATTERN = /\Ask_live_[A-Za-z0-9]{99}\z/

        private

        def valid_format?(token_value)
          return false unless token_value

          token_value.match?(TOKEN_PATTERN)
        end

        def verify_partner_token(token_value)
          response = make_stripe_request(token_value)
          analyze_stripe_response(response)
        end

        def make_stripe_request(token_value)
          # Stripe uses HTTP Basic with the secret key as the username and an
          # empty password.
          encoded = Base64.strict_encode64("#{token_value}:")
          headers = {
            'Authorization' => "Basic #{encoded}",
            'Accept' => 'application/json'
          }

          make_request(API_ENDPOINT, method: :get, headers: headers)
        end

        def analyze_stripe_response(response)
          case response.code.to_i
          when 200
            token_response(:active)
          when 401
            token_response(:inactive)
          when 429
            raise RateLimitError, "Stripe API rate limited: #{response.code}"
          when 500, 502, 503, 504
            raise NetworkError, "Stripe service error: #{response.code}"
          else
            token_response(:unknown)
          end
        end
      end
    end
  end
end
