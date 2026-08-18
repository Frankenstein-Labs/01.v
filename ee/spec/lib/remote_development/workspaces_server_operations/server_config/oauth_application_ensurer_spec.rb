# frozen_string_literal: true

require "spec_helper"

RSpec.describe ::RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationEnsurer, feature_category: :workspaces do
  include TestRequestHelpers

  let_it_be(:organization) { create(:organization) }

  let(:oauth_application_attributes) do
    {
      name: "App Name",
      redirect_uri: "https://example.com/redirect/uri",
      scopes: "openid",
      trusted:
        RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator::TRUSTED,
      confidential:
        RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator::CONFIDENTIAL,
      organization_id: organization.id
    }
  end

  let(:request) { test_request }
  let(:context) do
    {
      oauth_application_attributes: oauth_application_attributes,
      request: request
    }
  end

  subject(:returned_value) { described_class.ensure(context) }

  context "when application does not already exist" do
    it "creates the application" do
      expect { returned_value }.to change { Doorkeeper::Application.count }.by(1)

      id = returned_value[:workspaces_oauth_application].id
      expect(Doorkeeper::Application.find(id).attributes).to include(oauth_application_attributes.stringify_keys)
    end
  end

  context "when application already exists" do
    let!(:existing_application) { create(:workspaces_oauth_application) }

    it "returns the existing application and does not create a new one" do
      expect { returned_value }.not_to change { Doorkeeper::Application.count }

      expect(returned_value[:workspaces_oauth_application].id).to eq(existing_application.id)
    end
  end

  context "when application already exists but has been updated with incorrect values" do
    let!(:incorrect_workspaces_oauth_application) do
      confidential =
        !RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator::CONFIDENTIAL
      create(
        :workspaces_oauth_application,
        name: "not the right name",
        redirect_uri: "https://not-the-right-uri",
        scopes: "api",
        trusted:
          !RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator::TRUSTED,
        confidential:
          confidential
      )
    end

    let(:workspaces_oauth_application_id) { incorrect_workspaces_oauth_application.id }

    it "returns the existing application and does not create a new one" do
      expect { returned_value }.not_to change { Doorkeeper::Application.count }

      id = returned_value[:workspaces_oauth_application].id
      expect(id).to eq(incorrect_workspaces_oauth_application.id)
      expect(Doorkeeper::Application.find(id).attributes).to include(oauth_application_attributes.stringify_keys)
    end
  end
end
