# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::WorkspaceHostParser, feature_category: :workspaces do
  include ResultMatchers

  let(:context) do
    {
      workspace_host: workspace_host,
      user_id: 123
    }
  end

  subject(:result) do
    described_class.parse_workspace_host(context)
  end

  describe "#parse_workspace_host" do
    context "when workspace host is valid" do
      context "with a simple hostname" do
        let(:workspace_host) { "60001-workspace-abc123.example.com" }

        it "returns an ok Result with parsed port and workspace name" do
          expect(result).to be_ok_result do |returned_context|
            expect(returned_context).to eq(
              context.merge(
                port: "60001",
                workspace_name: "workspace-abc123"
              )
            )
          end
        end
      end

      context "with a full URL" do
        let(:workspace_host) { "https://60001-workspace-xyz.example.com/path" }

        it "returns an ok Result with parsed port and workspace name from hostname" do
          expect(result).to be_ok_result do |returned_context|
            expect(returned_context).to eq(
              context.merge(
                port: "60001",
                workspace_name: "workspace-xyz"
              )
            )
          end
        end
      end
    end

    context "when workspace host is invalid" do
      context "when hostname is blank after URL parsing" do
        let(:workspace_host) { "https://" }

        it "returns an err Result with INVALID_HOST status" do
          expect(result).to be_err_result do |message|
            expect(message).to be_a RemoteDevelopment::Messages::WorkspaceAuthorizeUserAccessFailed
            expect(message.content).to eq({ status: "INVALID_HOST" })
          end
        end
      end

      context "when workspace host is empty string" do
        let(:workspace_host) { "" }

        it "returns an err Result with INVALID_HOST status" do
          expect(result).to be_err_result do |message|
            expect(message).to be_a RemoteDevelopment::Messages::WorkspaceAuthorizeUserAccessFailed
            expect(message.content).to eq({ status: "INVALID_HOST" })
          end
        end
      end

      context "when port is missing (no hyphen in subdomain)" do
        let(:workspace_host) { "workspace.example.com" }

        it "returns an err Result with INVALID_HOST status" do
          expect(result).to be_err_result do |message|
            expect(message).to be_a RemoteDevelopment::Messages::WorkspaceAuthorizeUserAccessFailed
            expect(message.content).to eq({ status: "INVALID_HOST" })
          end
        end
      end

      context "when workspace name is missing" do
        let(:workspace_host) { "60001-.example.com" }

        it "returns an err Result with INVALID_HOST status" do
          expect(result).to be_err_result do |message|
            expect(message).to be_a RemoteDevelopment::Messages::WorkspaceAuthorizeUserAccessFailed
            expect(message.content).to eq({ status: "INVALID_HOST" })
          end
        end
      end

      context "when URL is malformed" do
        let(:workspace_host) { "https://invalid url with spaces" }

        it "returns an err Result with INVALID_HOST status" do
          expect(result).to be_err_result do |message|
            expect(message).to be_a RemoteDevelopment::Messages::WorkspaceAuthorizeUserAccessFailed
            expect(message.content).to eq({ status: "INVALID_HOST" })
          end
        end
      end
    end
  end
end
