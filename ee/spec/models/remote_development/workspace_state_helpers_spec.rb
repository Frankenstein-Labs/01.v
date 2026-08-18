# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceStateHelpers, feature_category: :workspaces do
  include_context "with constant modules"

  let(:fake_workspace_class) do
    Class.new do
      include RemoteDevelopment::WorkspaceStateHelpers

      attr_accessor :desired_state, :actual_state

      # @param [String] desired_state
      # @param [String] actual_state
      # @return [Object]
      def initialize(desired_state: nil, actual_state: nil)
        @desired_state = desired_state
        @actual_state = actual_state
      end
    end
  end

  shared_examples "state helpers behavior" do |state_type:|
    let(:underscored_state) { state.underscore }

    it "returns true" do
      # Dynamically test the positive case, for example `desired_state_terminated?` should be true
      # for desired_state of `Terminated`
      expect(fake_workspace.send(:"#{state_type}_state_#{underscored_state}?")).to be(true)
    end

    it "returns false" do
      # Dynamically test the negatie case, for example `desired_state_terminated?` should be false
      # for desired_state of `SomeOtherState`
      fake_workspace.send(:"#{state_type}_state=", "SomeOtherState")
      expect(fake_workspace.send(:"#{state_type}_state_#{underscored_state}?")).to be(false)
    end
  end

  describe "actual_state helpers" do
    using RSpec::Parameterized::TableSyntax

    where(:state) do
      # NOTE: To add or remove a test for an actual_state helper like `actual_state_terminated?`,
      #       add or remove the state from this array.
      [
        states_module::TERMINATED
      ]
    end

    with_them do
      let(:fake_workspace) { fake_workspace_class.new(actual_state: state) }

      it_behaves_like "state helpers behavior", state_type: "actual"
    end
  end

  describe "desired_state helpers" do
    using RSpec::Parameterized::TableSyntax

    where(:state) do
      # NOTE: To add or remove a test for a desired_state helper like `desired_state_terminated?`,
      #       add or remove the state from this array.
      [
        states_module::RUNNING,
        states_module::RESTART_REQUESTED,
        states_module::STOPPED,
        states_module::TERMINATED
      ]
    end

    with_them do
      let(:fake_workspace) { fake_workspace_class.new(desired_state: state) }

      it_behaves_like "state helpers behavior", state_type: "desired"
    end
  end
end
