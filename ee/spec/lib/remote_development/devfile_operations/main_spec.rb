# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::DevfileOperations::Main, feature_category: :workspaces do
  let(:context_passed_along_steps) { {} }
  let(:processed_devfile) { { test: "value" } }

  let(:rop_steps) do
    [
      [RemoteDevelopment::DevfileOperations::DevfileProcessor, :and_then],
      [observer_class, observer_method],
      [RemoteDevelopment::DevfileOperations::ResponseBuilder, :and_then]
    ]
  end

  describe "happy path" do
    let(:ok_message_content) { { ok_details: "Everything is OK!" } }
    let(:observer_class) { RemoteDevelopment::DevfileOperations::Observer }
    let(:observer_method) { :inspect_ok }

    let(:expected_response) do
      {
        status: :success,
        payload: ok_message_content
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
              .with_ok_result_for_step(
                {
                  step_class: RemoteDevelopment::DevfileOperations::ResponseBuilder,
                  returned_message: RemoteDevelopment::Messages::DevfileValidateSuccessful.new(ok_message_content)
                }
              )
              .and_return_expected_value(expected_response)
    end
  end

  describe "error cases" do
    let(:observer_class) { RemoteDevelopment::DevfileOperations::ErrorsObserver }
    let(:observer_method) { :inspect_err }
    let(:error_details) { "some error details" }
    let(:err_message_content) { { details: error_details } }

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
          "when DevfileProcessor returns DevfileYamlParseFailed",
          {
            step_class: RemoteDevelopment::DevfileOperations::DevfileProcessor,
            returned_message: lazy { RemoteDevelopment::Messages::DevfileYamlParseFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Devfile yaml parse failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when DevfileProcessor returns DevfileRestrictionsFailed",
          {
            step_class: RemoteDevelopment::DevfileOperations::DevfileProcessor,
            returned_message: lazy { RemoteDevelopment::Messages::DevfileRestrictionsFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Devfile restrictions failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when DevfileProcessor returns DevfileFlattenFailed",
          {
            step_class: RemoteDevelopment::DevfileOperations::DevfileProcessor,
            returned_message: lazy { RemoteDevelopment::Messages::DevfileFlattenFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Devfile flatten failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when an unmatched error is returned, an exception is raised",
          {
            step_class: RemoteDevelopment::DevfileOperations::DevfileProcessor,
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
