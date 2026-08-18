# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe ::RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator, feature_category: :workspaces do
  let(:expected_redirect_uri_scheme) { "http" }
  let(:default_organization_id) { 1 }

  let(:expected_oauth_application_attributes) do
    {
      name: "GitLab Workspaces",
      redirect_uri: "#{expected_redirect_uri_scheme}://host:3000/-/kubernetes-agent/workspaces/oauth/redirect",
      scopes: "openid",
      trusted:
        RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator::TRUSTED,
      confidential:
        RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator::CONFIDENTIAL,
      organization_id: default_organization_id
    }
  end

  let(:external_url_scheme) { "ws" }
  let(:gitlab_kas_external_url) { "#{external_url_scheme}://host:3000/-/kubernetes-agent" }
  let(:settings) { { gitlab_kas_external_url: gitlab_kas_external_url } }

  let(:context) { { settings: settings } }

  subject(:oauth_application_attributes) do
    described_class.generate(context)[:oauth_application_attributes]
  end

  before do
    organization = instance_double("Organizations::Organization", id: default_organization_id) # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
    stub_const("Organizations::Organization", Class.new)
    allow(Organizations::Organization).to receive(:first).and_return(organization)
  end

  it "returns the expected oauth application attributes" do
    expect(oauth_application_attributes).to eq(expected_oauth_application_attributes)
  end

  context "when no organization exists" do
    before do
      allow(Organizations::Organization).to receive(:first).and_return(nil)
    end

    it "sets organization_id to nil" do
      expected_attributes = expected_oauth_application_attributes.merge(organization_id: nil)
      expect(oauth_application_attributes).to eq(expected_attributes)
    end
  end

  context "when the external URL scheme is grpcs or wss" do
    let(:external_url_scheme) { "wss" }
    let(:expected_redirect_uri_scheme) { "https" }

    it "uses https as the redirect URI scheme" do
      expect(oauth_application_attributes).to eq(expected_oauth_application_attributes)
    end
  end
end
