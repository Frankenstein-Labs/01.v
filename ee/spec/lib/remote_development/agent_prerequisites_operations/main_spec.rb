# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::AgentPrerequisitesOperations::Main, feature_category: :workspaces do
  let(:context_passed_along_steps) { {} }
  let(:response_payload) do
    {
      shared_namespace: 'shared_namespace'
    }
  end

  let(:rop_steps) do
    [
      [RemoteDevelopment::AgentPrerequisitesOperations::ResponseBuilder, :map]
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
end
