# frozen_string_literal: true

module SecretsManagement
  module ErrorMapping
    ERROR_MAPPINGS = {
      /(metadata check-and-set parameter does not match|check-and-set parameter did not match)/ =>
        "This resource was recently modified. Refresh the page and try again to avoid overwriting newer changes."
    }.freeze

    PERMISSION_ERROR_PATTERNS = [
      /error executing cel program.*blocked authorization/,
      /unauthorized|forbidden|permission denied/i,
      /error executing cel program: invalid subject for user authentication/i
    ].freeze

    DEFAULT_ERROR_MESSAGE = "Internal server error."

    def permission_error?(error_message)
      return false if error_message.blank?

      PERMISSION_ERROR_PATTERNS.any? { |pattern| error_message.match?(pattern) }
    end

    def default_error?(error_message)
      error_message == DEFAULT_ERROR_MESSAGE
    end

    def sanitize_error_message(error_message)
      return DEFAULT_ERROR_MESSAGE if error_message.blank?

      ERROR_MAPPINGS.each do |pattern, user_message|
        return user_message if error_message.match?(pattern)
      end

      DEFAULT_ERROR_MESSAGE
    end
  end
end
