# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::WorkspacesServerOperations::ServerConfig::Main, feature_category: :workspaces do
  include TestRequestHelpers

  include_context "with remote development shared fixtures"

  let_it_be(:organization) { create(:organization) }

  let_it_be(:attributes_generator_class) do
    ::RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator
  end

  let_it_be(:gitlab_kas_external_scheme) { "ws" }
  # noinspection RubyResolve - Rubymine can't resolve gitlab_kas
  let_it_be(:gitlab_kas_external_url_without_scheme) { Gitlab.config.gitlab_kas.external_url.sub(%r{^\w+://}, '') }
  let_it_be(:gitlab_kas_external_url) do
    "#{gitlab_kas_external_scheme}://#{gitlab_kas_external_url_without_scheme}"
  end

  let_it_be(:expected_api_external_url) do
    uri_scheme = "http" # this is "http" because the original gitlab_kas_external_url scheme is "ws"
    "#{uri_scheme}://#{gitlab_kas_external_url_without_scheme}" \
      "/#{attributes_generator_class::API_EXTERNAL_URL_PATH_SEGMENT}"
  end

  let_it_be(:expected_oauth_redirect_url) do
    "#{expected_api_external_url}/#{attributes_generator_class::OAUTH_REDIRECT_URI_PATH_SEGMENT}"
  end

  # noinspection HttpUrlsUsage,RubyResolve
  let(:expected_oauth_application_attributes) do
    {
      name: attributes_generator_class::OAUTH_NAME,
      redirect_uri: expected_oauth_redirect_url,
      scopes: "openid",
      trusted:
        RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator::TRUSTED,
      confidential:
        RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator::CONFIDENTIAL,
      organization_id: organization.id
    }
  end

  let(:settings) { { gitlab_kas_external_url: gitlab_kas_external_url } }

  let(:context) do
    {
      settings: settings,
      request: test_request
    }
  end

  subject(:response) do
    described_class.main(context)
  end

  shared_examples "expected server config response" do
    it "returns the expected server config response" do
      response

      oauth_application = ::Gitlab::CurrentSettings.current_application_settings.workspaces_oauth_application || raise

      expect(response).to eq(
        {
          status: :success,
          payload: {
            api_external_url: expected_api_external_url,
            oauth_client_id: oauth_application.uid,
            oauth_redirect_url: oauth_application.redirect_uri
          }
        }
      )
    end
  end

  context "when the oauth application does not yet exist" do
    it "creates the oauth application" do
      expect { response }.to change { Authn::OauthApplication.count }.by(1)
    end

    it "creates the oauth application with the correct organization_id" do
      response

      oauth_application = ::Gitlab::CurrentSettings.current_application_settings.workspaces_oauth_application

      expect(oauth_application.organization_id).to eq(organization.id)
    end

    it_behaves_like("expected server config response")
  end

  context "when the oauth application already exists" do
    let!(:workspaces_oauth_application) { create(:workspaces_oauth_application) }

    shared_examples "oauth application already exists" do
      it "does not create the oauth application" do
        expect { response }.not_to change { Authn::OauthApplication.count }
      end

      it "has the expected attributes for the oauth application" do
        response

        actual_oauth_application_attributes = workspaces_oauth_application.reload.attributes

        expect(actual_oauth_application_attributes).to include expected_oauth_application_attributes.stringify_keys
      end
    end

    context "when oauth attributes are already all correct" do
      it_behaves_like("oauth application already exists")

      it_behaves_like("expected server config response")
    end

    context "when oauth attributes have been changed" do
      before do
        confidential =
          RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator::CONFIDENTIAL
        workspaces_oauth_application.update!(
          name: "not the right name",
          redirect_uri: "https://not-the-right-uri",
          scopes: "api",
          trusted:
            !RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator::TRUSTED,
          confidential: confidential
        )
      end

      it_behaves_like("oauth application already exists")

      it_behaves_like("expected server config response")
    end
  end
end
