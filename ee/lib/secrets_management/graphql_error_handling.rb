# frozen_string_literal: true

module SecretsManagement
  module GraphqlErrorHandling
    extend ActiveSupport::Concern
    include SecretsManagement::ErrorMapping

    included do
      prepend ErrorWrapper
    end

    module ErrorWrapper
      def resolve(*args, **kwargs, &block)
        super
      rescue SecretsManagement::SecretsManagerClient::ApiError => e
        if permission_error?(e.message)
          raise_resource_not_available_error!
        else
          sanitized_message = sanitize_error_message(e.message)
          track_exception(e) if default_error?(sanitized_message)

          raise Gitlab::Graphql::Errors::BaseError,
            sanitized_message
        end
      end

      def track_exception(exception)
        Gitlab::ErrorTracking.track_exception(
          exception,
          feature_category: :secrets_management
        )
      end
    end
  end
end
