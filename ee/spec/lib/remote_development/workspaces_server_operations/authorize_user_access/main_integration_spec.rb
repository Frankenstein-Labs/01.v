# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::Main, feature_category: :workspaces do
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:workspace) { create(:workspace, user: user) }
  let_it_be(:dns_zone) { "integration-spec-workspaces.localdev.me" }
  let_it_be(:port) { "60001" }

  let(:workspace_host) { "#{port}-#{workspace.name}.#{dns_zone}" }

  subject(:response) do
    described_class.main(
      workspace_host: workspace_host,
      user_id: user_id
    )
  end

  shared_examples "successful authorization response" do
    it "returns success with authorized status and workspace info" do
      expect(response).to eq({
        status: :success,
        payload: {
          status: "AUTHORIZED",
          info: {
            port: port,
            workspace_id: workspace.id
          }
        }
      })
    end
  end

  shared_examples "failed authorization response" do |expected_status|
    it "returns success with failed status and empty info" do
      expect(response).to eq({
        status: :success,
        payload: {
          status: expected_status,
          info: {}
        }
      })
    end
  end

  context "when user is authorized" do
    let(:user_id) { user.id }

    it_behaves_like "successful authorization response"
  end

  context "when user is not authorized" do
    let(:user_id) { other_user.id }

    it_behaves_like "failed authorization response", "NOT_AUTHORIZED"
  end

  context "when workspace does not exist" do
    let(:user_id) { user.id }
    let(:workspace_host) { "#{port}-nonexistent-workspace.#{dns_zone}" }

    it_behaves_like "failed authorization response", "WORKSPACE_NOT_FOUND"
  end

  context "when workspace host is invalid" do
    let(:user_id) { user.id }

    context "when host format is completely invalid" do
      let(:workspace_host) { "invalid-format" }

      it_behaves_like "failed authorization response", "WORKSPACE_NOT_FOUND"
    end

    context "when host is missing port" do
      let(:workspace_host) { "#{workspace.name}.#{dns_zone}" }

      it_behaves_like "failed authorization response", "WORKSPACE_NOT_FOUND"
    end

    context "when host is missing workspace name" do
      let(:workspace_host) { "#{port}-.#{dns_zone}" }

      it_behaves_like "failed authorization response", "INVALID_HOST"
    end

    context "when host is empty" do
      let(:workspace_host) { "" }

      it_behaves_like "failed authorization response", "INVALID_HOST"
    end
  end

  context "when workspace host is a full URL" do
    let(:user_id) { user.id }
    let(:workspace_host) { "https://#{port}-#{workspace.name}.#{dns_zone}/path" }

    it_behaves_like "successful authorization response"
  end

  context "when workspace host contains invalid URI characters" do
    let(:user_id) { user.id }
    let(:workspace_host) { "https://#{port}-#{workspace.name}.#{dns_zone}/path with spaces" }

    it_behaves_like "failed authorization response", "INVALID_HOST"
  end
end
