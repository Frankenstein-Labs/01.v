# frozen_string_literal: true

require 'spec_helper'

Messages = RemoteDevelopment::Messages

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::Creator, feature_category: :workspaces do
  let(:context_passed_along_steps) { {} }
  let(:rop_steps) do
    [
      [RemoteDevelopment::WorkspaceOperations::Create::CreatorBootstrapper, :map],
      [RemoteDevelopment::WorkspaceOperations::Create::PersonalAccessTokenCreator, :and_then],
      [RemoteDevelopment::WorkspaceOperations::Create::WorkspaceCreator, :and_then],
      [RemoteDevelopment::WorkspaceOperations::Create::WorkspaceVariablesCreator, :and_then],
      [RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::Main, :map],
      [RemoteDevelopment::WorkspaceOperations::Create::WorkspaceAgentkStateCreator, :and_then]
    ]
  end

  describe "happy path" do
    let(:expected_value) do
      Gitlab::Fp::Result.ok(context_passed_along_steps)
    end

    it "returns expected response" do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect do
        described_class.create(context_passed_along_steps) # rubocop:disable Rails/SaveBang -- this is not an ActiveRecord call
      end
        .to invoke_rop_steps(rop_steps)
              .from_main_class(described_class)
              .with_context_passed_along_steps(context_passed_along_steps)
              .and_return_expected_value(expected_value)
    end
  end

  describe "error cases" do
    let(:error_details) { "some error details" }
    let(:err_message_content) { { errors: error_details, context: context_passed_along_steps } }
    let(:rop_steps) do
      [
        [RemoteDevelopment::WorkspaceOperations::Create::CreatorBootstrapper, :map],
        [RemoteDevelopment::WorkspaceOperations::Create::PersonalAccessTokenCreator, :and_then],
        [RemoteDevelopment::WorkspaceOperations::Create::WorkspaceCreator, :and_then],
        [RemoteDevelopment::WorkspaceOperations::Create::WorkspaceVariablesCreator, :and_then],
        [RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::Main, :map],
        [RemoteDevelopment::WorkspaceOperations::Create::WorkspaceAgentkStateCreator, :and_then]
      ]
    end

    shared_examples "rop invocation with error response" do
      it "returns expected response" do
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect do
          described_class.create(context_passed_along_steps) # rubocop:disable Rails/SaveBang -- this is not an ActiveRecord call
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
          "when PersonalAccessTokenCreator returns PersonalAccessTokenModelCreateFailed",
          {
            step_class: RemoteDevelopment::WorkspaceOperations::Create::PersonalAccessTokenCreator,
            returned_message: lazy { Messages::PersonalAccessTokenModelCreateFailed.new(err_message_content) }
          },
          lazy { Gitlab::Fp::Result.err(Messages::WorkspaceCreateFailed.new(err_message_content)) }
        ],
        [
          "when WorkspaceCreator returns WorkspaceModelCreateFailed",
          {
            step_class: RemoteDevelopment::WorkspaceOperations::Create::WorkspaceCreator,
            returned_message: lazy { Messages::WorkspaceModelCreateFailed.new(err_message_content) }
          },
          lazy { Gitlab::Fp::Result.err(Messages::WorkspaceCreateFailed.new(err_message_content)) }
        ],
        [
          "when WorkspaceVariablesCreator returns WorkspaceVariablesModelCreateFailed",
          {
            step_class: RemoteDevelopment::WorkspaceOperations::Create::WorkspaceVariablesCreator,
            returned_message: lazy { Messages::WorkspaceVariablesModelCreateFailed.new(err_message_content) }
          },
          lazy { Gitlab::Fp::Result.err(Messages::WorkspaceCreateFailed.new(err_message_content)) }
        ],
        [
          "when WorkspaceAgentkState returns WorkspaceAgentkStateCreateFailed",
          {
            step_class: RemoteDevelopment::WorkspaceOperations::Create::WorkspaceAgentkStateCreator,
            returned_message: lazy { Messages::WorkspaceAgentkStateCreateFailed.new(err_message_content) }
          },
          lazy { Gitlab::Fp::Result.err(Messages::WorkspaceCreateFailed.new(err_message_content)) }
        ],
      ]
    end
    # rubocop:enable Style/TrailingCommaInArrayLiteral
    with_them do
      it_behaves_like "rop invocation with error response"
    end
  end
end
