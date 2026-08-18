# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::WorkspaceFinder, feature_category: :workspaces do
  include ResultMatchers

  let_it_be(:user) { create(:user) }
  let(:workspace_name) { "workspace-abc123" }
  let(:context) do
    {
      workspace_host: "60001-#{workspace_name}.example.com",
      user_id: user.id,
      port: "60001",
      workspace_name: workspace_name
    }
  end

  subject(:result) do
    described_class.find_workspace(context)
  end

  describe "#find_workspace" do
    context "when workspace exists" do
      let_it_be(:workspace) { create(:workspace, name: "workspace-abc123", user: user) }

      it "returns an ok Result with the workspace added to context" do
        expect(result).to be_ok_result do |returned_context|
          expect(returned_context).to eq(
            context.merge(workspace: workspace)
          )
        end
      end
    end

    context "when workspace does not exist" do
      it "returns an err Result with WORKSPACE_NOT_FOUND status" do
        expect(result).to be_err_result do |message|
          expect(message).to be_a RemoteDevelopment::Messages::WorkspaceAuthorizeUserAccessFailed
          expect(message.content).to eq({ status: "WORKSPACE_NOT_FOUND" })
        end
      end
    end

    context "when workspace name is different" do
      let(:different_workspace_name) { "different-workspace" }
      let(:context) do
        {
          workspace_host: "60001-#{different_workspace_name}.example.com",
          user_id: user.id,
          port: "60001",
          workspace_name: different_workspace_name
        }
      end

      it "returns an err Result when not found" do
        expect(result).to be_err_result do |message|
          expect(message).to be_a RemoteDevelopment::Messages::WorkspaceAuthorizeUserAccessFailed
          expect(message.content).to eq({ status: "WORKSPACE_NOT_FOUND" })
        end
      end
    end
  end
end
