# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::DevfileOperations::DevfileProcessor, feature_category: :workspaces do
  let(:context_passed_along_steps) { {} }
  let(:processed_devfile) { { test: "value" } }

  let(:rop_steps) do
    [
      [RemoteDevelopment::DevfileOperations::YamlParser, :and_then],
      [RemoteDevelopment::DevfileOperations::RestrictionsEnforcer, :and_then],
      [RemoteDevelopment::DevfileOperations::Flattener, :and_then],
      [RemoteDevelopment::DevfileOperations::RestrictionsEnforcer, :and_then]
    ]
  end

  describe "happy path" do
    let(:context_passed_along_steps) do
      {
        ok_details: "Everything is OK!",
        processed_devfile: processed_devfile
      }
    end

    let(:expected_response) do
      Gitlab::Fp::Result.ok(context_passed_along_steps)
    end

    it "returns expected response" do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect do
        described_class.validate(context_passed_along_steps)
      end
        .to invoke_rop_steps(rop_steps)
              .from_main_class(described_class)
              .with_context_passed_along_steps(context_passed_along_steps)
              .and_return_expected_value(expected_response)
    end
  end

  describe "error cases" do
    let(:error_details) { "some error details" }
    let(:err_message_content) { { details: error_details } }

    shared_examples "rop invocation with error response" do
      it "returns expected response" do
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect do
          described_class.validate(context_passed_along_steps)
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
          "when YamlParser returns DevfileYamlParseFailed",
          {
            step_class: RemoteDevelopment::DevfileOperations::YamlParser,
            returned_message: lazy { RemoteDevelopment::Messages::DevfileYamlParseFailed.new(err_message_content) }
          },
          lazy { Gitlab::Fp::Result.err(RemoteDevelopment::Messages::DevfileYamlParseFailed.new(err_message_content)) }
        ],
        [
          "when RestrictionsEnforcer returns DevfileRestrictionsFailed",
          {
            step_class: RemoteDevelopment::DevfileOperations::RestrictionsEnforcer,
            returned_message: lazy { RemoteDevelopment::Messages::DevfileRestrictionsFailed.new(err_message_content) }
          },
          lazy do
            Gitlab::Fp::Result.err(RemoteDevelopment::Messages::DevfileRestrictionsFailed.new(err_message_content))
          end
        ],
        [
          "when Flattener returns DevfileFlattenFailed",
          {
            step_class: RemoteDevelopment::DevfileOperations::Flattener,
            returned_message: lazy { RemoteDevelopment::Messages::DevfileFlattenFailed.new(err_message_content) }
          },
          lazy { Gitlab::Fp::Result.err(RemoteDevelopment::Messages::DevfileFlattenFailed.new(err_message_content)) }
        ],
      ]
    end
    # rubocop:enable Style/TrailingCommaInArrayLiteral

    with_them do
      it_behaves_like "rop invocation with error response"
    end
  end
end
