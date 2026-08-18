# frozen_string_literal: true

module Security
  module SecretDetection
    module PartnerTokens
      class Registry
        RegistryError = Class.new(StandardError)
        UnsupportedTokenTypeError = Class.new(RegistryError)

        PARTNERS = {
          'AWS' => {
            client_class: ::Security::SecretDetection::PartnerTokens::AwsClient,
            rate_limit_key: :partner_aws_api,
            enabled: true
          }.freeze,
          # GCP - multiple rule types
          'GCP API key' => {
            client_class: ::Security::SecretDetection::PartnerTokens::GcpClient,
            rate_limit_key: :partner_gcp_api,
            enabled: true
          }.freeze,
          'GCP OAuth client secret' => {
            client_class: ::Security::SecretDetection::PartnerTokens::GcpClient,
            rate_limit_key: :partner_gcp_api,
            enabled: true
          }.freeze,
          'Google (GCP) Service-account' => {
            client_class: ::Security::SecretDetection::PartnerTokens::GcpClient,
            rate_limit_key: :partner_gcp_api,
            enabled: true
          }.freeze,
          # Postman
          'Postman API token' => {
            client_class: ::Security::SecretDetection::PartnerTokens::PostmanClient,
            rate_limit_key: :partner_postman_api,
            enabled: true
          }.freeze,
          # GitHub
          'Github Personal Access Token' => {
            client_class: ::Security::SecretDetection::PartnerTokens::GithubClient,
            rate_limit_key: :partner_github_api,
            enabled: true
          }.freeze,
          # OpenAI
          'OpenAiProjectKey' => {
            client_class: ::Security::SecretDetection::PartnerTokens::OpenaiClient,
            rate_limit_key: :partner_openai_api,
            enabled: true
          }.freeze,
          # Anthropic
          'anthropic_key' => {
            client_class: ::Security::SecretDetection::PartnerTokens::AnthropicClient,
            rate_limit_key: :partner_anthropic_api,
            enabled: true
          }.freeze,
          # Heroku
          'Heroku API Key' => {
            client_class: ::Security::SecretDetection::PartnerTokens::HerokuClient,
            rate_limit_key: :partner_heroku_api,
            enabled: true
          }.freeze,
          # Stripe
          'StripeLiveSecretKey' => {
            client_class: ::Security::SecretDetection::PartnerTokens::StripeClient,
            rate_limit_key: :partner_stripe_api,
            enabled: true
          }.freeze,
          # Datadog
          'DataDogAPIKey' => {
            client_class: ::Security::SecretDetection::PartnerTokens::DatadogClient,
            rate_limit_key: :partner_datadog_api,
            enabled: true
          }.freeze,
          # SendGrid
          'Sendgrid API token' => {
            client_class: ::Security::SecretDetection::PartnerTokens::SendgridClient,
            rate_limit_key: :partner_sendgrid_api,
            enabled: true
          }.freeze
        }.freeze

        class << self
          def partner_for(token_type)
            config = PARTNERS[token_type.to_s]
            return unless config && config[:enabled]

            config
          end

          def client_for(token_type)
            config = partner_for(token_type)
            return unless config

            config[:client_class].new
          rescue NameError => e
            Gitlab::ErrorTracking.track_exception(
              e,
              token_type: token_type,
              client_class: config[:client_class]
            )
            nil
          end

          def rate_limit_key_for(token_type)
            config = partner_for(token_type)
            return unless config

            config[:rate_limit_key]
          end
        end
      end
    end
  end
end
