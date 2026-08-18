# frozen_string_literal: true

module EE
  module Gitlab
    module Auth
      module AuthFinders
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          include ::Gitlab::Auth::RemoteDevelopment::AuthFinders
        end

        def find_user_from_geo_token
          return unless geo_api_request?

          token = current_request.authorization
          return unless ::Gitlab::Geo::JwtRequestDecoder.geo_auth_attempt?(token)

          token_data = parse_geo_token(token)
          raise(::Gitlab::Auth::UnauthorizedError) unless
            token_data.is_a?(Hash) && token_data[:scope] == ::Gitlab::Geo::API_SCOPE

          ::User.find(token_data[:authenticating_user_id])
        rescue ::ActiveRecord::RecordNotFound
          raise(::Gitlab::Auth::UnauthorizedError)
        end

        def parse_geo_token(token)
          geo_jwt_decoder = ::Gitlab::Geo::JwtRequestDecoder.new(token)
          geo_jwt_decoder.decode
        rescue ::Gitlab::Geo::InvalidDecryptionKeyError, ::Gitlab::Geo::InvalidSignatureTimeError => e
          ::Gitlab::ErrorTracking.track_exception(e)
          nil
        end

        override :find_oauth_access_token
        def find_oauth_access_token
          return if scim_request?

          super
        end

        def scim_request?
          current_request.path.starts_with?("/api/scim/")
        end

        def geo_api_request?
          current_request.path.starts_with?("/api/#{::API::API.version}/geo/")
        end

        override :find_user_from_job_token
        def find_user_from_job_token
          user = super
          return unless user

          audit_job_token_authentication(user)

          user
        end

        def runner_controller_token_from_authorization_token
          return unless route_authentication_setting[:runner_controller_token_allowed]

          self.current_token = current_request.headers[::Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER]

          return unless current_token.present?

          ::Ci::RunnerControllerToken.active.find_by_token(current_token.to_s)
        end

        private

        def audit_job_token_authentication(user)
          # rubocop:disable Gitlab/ModuleWithInstanceVariables -- Already used in super
          audit_context = {
            name: "user_authenticated_using_job_token",
            author: user,
            scope: @current_authenticated_job.project,
            target: @current_authenticated_job,
            target_details: @current_authenticated_job.id.to_s,
            message: "#{user.name} authenticated using job token of job id: #{@current_authenticated_job.id}"
          }
          # rubocop:enable Gitlab/ModuleWithInstanceVariables

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end
      end
    end
  end
end
