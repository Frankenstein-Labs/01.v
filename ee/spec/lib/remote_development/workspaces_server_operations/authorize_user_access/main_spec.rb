# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::Main, feature_category: :workspaces do
  let(:workspace_host) { "60001-workspace-abc123.example.com" }
  let(:user_id) { 123 }
  let(:context_passed_along_steps) { { workspace_host: workspace_host, user_id: user_id } }

  let(:rop_steps) do
    [
      [RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::WorkspaceHostParser, :and_then],
      [RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::WorkspaceFinder, :and_then],
      [RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::Authorizer, :and_then]
    ]
  end

  describe "happy path" do
    let(:response_payload) do
      {
        status: "AUTHORIZED",
        info: {
          port: "60001",
          workspace_id: 456
        }
      }
    end

    let(:context_passed_along_steps) do
      {
        workspace_host: workspace_host,
        user_id: user_id,
        response_payload: response_payload
      }
    end

    let(:expected_response) do
      {
        status: :success,
        payload: response_payload
      }
    end

    it "returns expected response" do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect do
        described_class.main(context_passed_along_steps)
      end
        .to invoke_rop_steps(rop_steps)
              .from_main_class(described_class)
              .with_context_passed_along_steps(context_passed_along_steps)
              .and_return_expected_value(expected_response)
    end
  end

  describe "error cases" do
    shared_examples "rop invocation with error response" do
      it "returns expected response" do
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect do
          described_class.main(context_passed_along_steps)
        end
          .to invoke_rop_steps(rop_steps)
                .from_main_class(described_class)
                .with_context_passed_along_steps(context_passed_along_steps)
                .with_err_result_for_step(err_result_for_step)
                .and_return_expected_value(expected_response)
      end
    end

    # rubocop:disable Style/TrailingCommaInArrayLiteral -- let the last element have a comma for simpler diffs
    where(:case_name, :err_result_for_step, :expected_response) do
      [
        [
          "when WorkspaceHostParser returns WorkspaceAuthorizeUserAccessFailed with INVALID_HOST",
          {
            step_class: RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::WorkspaceHostParser,
            returned_message: lazy { RemoteDevelopment::Messages::WorkspaceAuthorizeUserAccessFailed.new({ status: "INVALID_HOST" }) }
          },
          {
            status: :success,
            payload: {
              status: "INVALID_HOST",
              info: {}
            }
          },
        ],
        [
          "when WorkspaceFinder returns WorkspaceAuthorizeUserAccessFailed with WORKSPACE_NOT_FOUND",
          {
            step_class: RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::WorkspaceFinder,
            returned_message: lazy { RemoteDevelopment::Messages::WorkspaceAuthorizeUserAccessFailed.new({ status: "WORKSPACE_NOT_FOUND" }) }
          },
          {
            status: :success,
            payload: {
              status: "WORKSPACE_NOT_FOUND",
              info: {}
            }
          },
        ],
        [
          "when Authorizer returns WorkspaceAuthorizeUserAccessFailed with NOT_AUTHORIZED",
          {
            step_class: RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::Authorizer,
            returned_message: lazy { RemoteDevelopment::Messages::WorkspaceAuthorizeUserAccessFailed.new({ status: "NOT_AUTHORIZED" }) }
          },
          {
            status: :success,
            payload: {
              status: "NOT_AUTHORIZED",
              info: {}
            }
          },
        ],
        [
          "when an unmatched error is returned, an exception is raised",
          {
            step_class: RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::WorkspaceHostParser,
            returned_message: lazy { Class.new(Gitlab::Fp::Message).new({ status: "UNKNOWN" }) }
          },
          Gitlab::Fp::UnmatchedResultError
        ],
      ]
    end
    # rubocop:enable Style/TrailingCommaInArrayLiteral

    with_them do
      it_behaves_like "rop invocation with error response"
    end
  end
end
