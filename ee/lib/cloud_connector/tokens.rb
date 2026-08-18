# frozen_string_literal: true

module CloudConnector
  # rubocop:disable Gitlab/ModuleWithInstanceVariables -- Not a mixin, valid use case.
  module Tokens
    extend self

    @key_loader = CachingKeyLoader.new

    # Retrieves a token for the specified unit primitive
    #
    # @param unit_primitive [Symbol] Requested unit primitive
    # @param resource [User], [Group], [Project] or [:instance]
    # @param extra_claims [Hash] Additional JWT claims to include
    # @return [String] JWT token
    def get(unit_primitive:, resource:, extra_claims: {}, feature_setting: nil)
      if use_self_signed_token?(unit_primitive, feature_setting: feature_setting)
        issue_token(resource, extra_claims)
      else
        cloud_connector_token
      end
    end

    def cloud_connector_token
      TokenLoader.new.token
    end

    private

    def issue_token(resource, extra_claims)
      jwk = @key_loader.private_jwk
      ::CloudConnector::TokenInstrumentation.instrument(jwk: jwk, operation_type: 'self_signed') do
        TokenIssuer.new(
          name_or_url: Doorkeeper::OpenidConnect.configuration.issuer,
          subject: Gitlab::CurrentSettings.uuid,
          realm: ::CloudConnector.gitlab_realm,
          active_add_ons: fetch_active_add_ons(resource),
          ttl: 1.hour,
          jwk: jwk,
          extra_claims: extra_claims
        ).token
      end
    end

    def fetch_active_add_ons(resource)
      add_on_names = GitlabSubscriptions::AddOn.names.keys
      GitlabSubscriptions::AddOnPurchase.for_active_add_ons(add_on_names, resource).uniq_normalized_add_on_names
    end

    def use_self_signed_token?(unit_primitive, feature_setting: nil)
      return true if ::Gitlab::Saas.feature_available?(:cloud_connector_self_signed_tokens)
      # This should be removed in https://gitlab.com/gitlab-org/gitlab/-/issues/543706
      return true if unit_primitive == :self_hosted_models

      feature_setting ||= ::Ai::FeatureSetting.feature_for_unit_primitive(unit_primitive)
      return true if feature_setting&.self_hosted?

      Gitlab::Utils.to_boolean(ENV['CLOUD_CONNECTOR_SELF_SIGN_TOKENS'])
    end
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables
end
