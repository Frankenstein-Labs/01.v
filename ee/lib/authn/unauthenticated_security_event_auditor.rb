# frozen_string_literal: true

module Authn
  class UnauthenticatedSecurityEventAuditor
    attr_reader :author, :scope, :authentication_method

    def initialize(user_or_login, authentication_method = 'STANDARD')
      if user_or_login.is_a?(User)
        @author = @scope = user_or_login
      else
        @author = ::Gitlab::Audit::UnauthenticatedAuthor.new(
          name: user_or_login.is_a?(String) ? user_or_login : nil
        )
        @scope = Gitlab::Audit::InstanceScope.new
      end

      @authentication_method = authentication_method
    end

    def execute
      context = {
        name: "login_failed_with_#{@authentication_method.downcase}_authentication",
        scope: @scope,
        author: @author,
        target: @author,
        message: "Failed to login with #{@authentication_method} authentication",
        additional_details: {
          failed_login: @authentication_method
        }
      }

      ::Gitlab::Audit::Auditor.audit(context)
    end
  end
end
