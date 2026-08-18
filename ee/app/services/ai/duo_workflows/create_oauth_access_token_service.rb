# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateOauthAccessTokenService
      include ::Services::ReturnServiceResponses

      def initialize(current_user:, organization:, workflow_definition: nil)
        @current_user = current_user
        @organization = organization
        @workflow_definition = workflow_definition
      end

      def execute
        ensure_oauth_application!
        token = create_oauth_access_token
        stick_to_database_load_balancer(token)
        success(oauth_access_token: token)
      end

      private

      attr_reader :current_user

      def create_oauth_access_token
        # OAuth tokens are hashed before being saved in the database, so we must
        # re-create them each time to retrieve the plaintext value
        # see https://gitlab.com/gitlab-org/gitlab/-/merge_requests/91501
        OauthAccessToken.create!(
          application_id: oauth_application.id,
          expires_in: 2.hours,
          resource_owner_id: current_user.id,
          organization: @organization,
          scopes: oauth_application.scopes.to_s
        )
      end

      def ensure_oauth_application!
        return if oauth_application&.scopes&.include?(::Gitlab::Auth::MCP_SCOPE.to_s)

        scopes = ::Gitlab::Auth::AI_WORKFLOW_SCOPES + [::Gitlab::Auth::MCP_SCOPE]

        # Add missing mcp scope if the application exists
        if oauth_application.present?
          oauth_application.update!(scopes: scopes)

          return
        end

        should_expire_cache = false

        application_settings.with_lock do
          # note: `with_lock` busts application_settings cache and will trigger another query.
          # We need to double check here so that requests previously waiting on the lock can
          # now just skip.
          next if oauth_application

          application = Authn::OauthApplication.new(
            name: 'GitLab Duo Agent Platform',
            redirect_uri: oauth_callback_url,
            scopes: scopes,
            trusted: true,
            confidential: false,
            organization: @organization
          )
          application.save!
          application_settings.update!(duo_workflow: { duo_workflow_oauth_application_id: application.id })
          should_expire_cache = true
        end

        # note: This needs to happen outside the transaction, but only if we actually changed something
        ::Gitlab::CurrentSettings.expire_current_application_settings if should_expire_cache
      end

      def application_settings
        ::Gitlab::CurrentSettings.current_application_settings
      end

      def oauth_application
        oauth_application_id = application_settings.duo_workflow_oauth_application_id
        return unless oauth_application_id

        Authn::OauthApplication.find_by_id(oauth_application_id)
      end

      def oauth_callback_url
        # This value is unused but cannot be nil
        Gitlab::Routing.url_helpers.root_url
      end

      def stick_to_database_load_balancer(token)
        # Newly created oauth tokens may not be synced to a replica before they are used in Duo features.
        # If a subsequent request comes in with the new token and we query a replica database then we may
        # not find the token and we'll get a 401. Sticking ensures that we keep
        # using the primary until the replicas are caught up to this point.
        ::OauthAccessToken.sticking.stick(:oauth_token, token.plaintext_token, hash_id: true)
      end
    end
  end
end
