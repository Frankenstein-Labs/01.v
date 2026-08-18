# frozen_string_literal: true

FactoryBot.define do
  # Factory for Workspaces OAuth application (renamed from workspaces_doorkeeper_application)
  factory :workspaces_oauth_application, class: 'Authn::OauthApplication', parent: :oauth_application do
    without_owner

    transient do
      app_attributes do
        RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator
          .generate({ settings: { gitlab_kas_external_url: Gitlab.config.gitlab_kas.external_url } })
          .fetch(:oauth_application_attributes)
      end
    end

    name { app_attributes[:name] }
    redirect_uri { app_attributes[:redirect_uri] }
    scopes { app_attributes[:scopes] }
    trusted { app_attributes[:trusted] }
    confidential { app_attributes[:confidential] }
    organization_id { app_attributes[:organization_id] }

    after(:create) do |oauth_app|
      settings = ::Gitlab::CurrentSettings.current_application_settings
      settings.update!(workspaces_oauth_application_id: oauth_app.id)
      ::Gitlab::CurrentSettings.expire_current_application_settings
    end
  end
end
