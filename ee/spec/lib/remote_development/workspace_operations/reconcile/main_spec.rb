# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Main, feature_category: :workspaces do
  let(:context_passed_along_steps) { {} }
  let(:response_payload) do
    {
      workspace_rails_infos: [],
      settings: { settings: 'some_Settings' }
    }
  end

  let(:rop_steps) do
    [
      [RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ParamsValidator, :and_then],
      [RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ParamsExtractor, :map],
      [RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ParamsToInfosConverter, :map],
      [RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfosObserver, :inspect_ok],
      [RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::WorkspacesFromAgentInfosUpdater, :map],
      [RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::OrphanedWorkspacesObserver, :inspect_ok],
      [RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::WorkspacesLifecycleManager, :map],
      [RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::WorkspacesToBeReturnedFinder, :map],
      [RemoteDevelopment::WorkspaceOperations::Reconcile::Output::ResponsePayloadBuilder, :map],
      [RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::WorkspacesToBeReturnedUpdater, :map],
      [RemoteDevelopment::WorkspaceOperations::Reconcile::Output::ResponsePayloadObserver, :inspect_ok]
    ]
  end

  describe "happy path" do
    let(:context_passed_along_steps) do
      {
        ok_details: "Everything is OK!",
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
    let(:error_details) { "some error details" }
    let(:err_message_content) { { details: error_details, context: context_passed_along_steps } }
    let(:rop_steps) do
      [
        [RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ParamsValidator, :and_then],
        [RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ParamsExtractor, :map],
        [RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ParamsToInfosConverter, :map],
        [RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::WorkspacesFromAgentInfosUpdater, :map],
        [RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::WorkspacesLifecycleManager, :map],
        [RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::WorkspacesToBeReturnedFinder, :map],
        [RemoteDevelopment::WorkspaceOperations::Reconcile::Output::ResponsePayloadBuilder, :map],
        [RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::WorkspacesToBeReturnedUpdater, :map]
      ]
    end

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
          "when ParamsValidator returns WorkspaceReconcileParamsValidationFailed",
          {
            step_class: RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ParamsValidator,
            returned_message: lazy { RemoteDevelopment::Messages::WorkspaceReconcileParamsValidationFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Workspace reconcile params validation failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when an unmatched error is returned, an exception is raised",
          {
            step_class: RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ParamsValidator,
            returned_message: lazy { Class.new(Gitlab::Fp::Message).new(err_message_content) }
          },
          Gitlab::Fp::UnmatchedResultError
        ]
      ]
    end
    # rubocop:enable Style/TrailingCommaInArrayLiteral

    with_them do
      it_behaves_like "rop invocation with error response"
    end
  end
end
