# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::Authorizer, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'
  include ResultMatchers

  let(:user_id) { 123 }
  let(:workspace_id) { 456 }
  let(:editor_port) { RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::WORKSPACE_EDITOR_PORT.to_s }
  let(:ssh_port) { RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::WORKSPACE_SSH_PORT.to_s }
  let(:port) { editor_port }
  let(:workspace_name) { "workspace-abc123" }
  let(:processed_devfile) { example_processed_devfile_yaml }
  let(:workspace) do
    instance_double(
      "RemoteDevelopment::Workspace",  # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      id: workspace_id,
      name: workspace_name,
      user_id: workspace_owner_id,
      processed_devfile: processed_devfile
    )
  end

  let(:context) do
    {
      workspace_host: "#{port}-#{workspace_name}.example.com",
      user_id: user_id,
      port: port,
      workspace_name: workspace_name,
      workspace: workspace
    }
  end

  subject(:result) do
    described_class.authorize(context)
  end

  describe "#authorize" do
    context "when user is authorized (owns the workspace)" do
      let(:workspace_owner_id) { user_id }

      it "returns an ok Result with authorized status and workspace info" do
        expect(result).to be_ok_result do |returned_context|
          expect(returned_context).to eq(
            context.merge(
              response_payload: {
                status: "AUTHORIZED",
                info: {
                  port: port,
                  workspace_id: workspace_id
                }
              }
            )
          )
        end
      end

      context "when port is not exposed for the workspace" do
        let(:port) { "10" }

        it "returns an err Result with PORT_NOT_FOUND status" do
          expect(result).to be_err_result do |message|
            expect(message).to be_a RemoteDevelopment::Messages::WorkspaceAuthorizeUserAccessFailed
            expect(message.content).to eq({ status: "PORT_NOT_FOUND" })
          end
        end
      end
    end

    context "when user is not authorized (does not own the workspace)" do
      let(:workspace_owner_id) { 789 } # Different user ID

      it "returns an err Result with NOT_AUTHORIZED status" do
        expect(result).to be_err_result do |message|
          expect(message).to be_a RemoteDevelopment::Messages::WorkspaceAuthorizeUserAccessFailed
          expect(message.content).to eq({ status: "NOT_AUTHORIZED" })
        end
      end
    end

    context "with different user and workspace IDs" do
      let(:user_id) { 999 }
      let(:workspace_id) { 888 }
      let(:workspace_owner_id) { user_id }

      it "returns authorized when IDs match" do
        expect(result).to be_ok_result do |returned_context|
          expect(returned_context[:response_payload]).to include(
            status: "AUTHORIZED",
            info: {
              port: port,
              workspace_id: workspace_id
            }
          )
        end
      end
    end

    context "with different port values" do
      let(:port) { ssh_port }
      let(:workspace_owner_id) { user_id }

      it "includes the correct port in the response" do
        expect(result).to be_ok_result do |returned_context|
          expect(returned_context[:response_payload][:info][:port]).to eq(ssh_port)
        end
      end
    end
  end
end
