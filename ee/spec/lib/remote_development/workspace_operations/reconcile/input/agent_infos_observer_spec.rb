# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfosObserver, feature_category: :workspaces do
  include_context "with constant modules"

  let(:agent) { instance_double("Clusters::Agent", id: 1) } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  let(:update_type) { RemoteDevelopment::WorkspaceOperations::Reconcile::UpdateTypes::PARTIAL }
  let(:logger) { instance_double(::Logger) }
  let(:normal_agent_info) do
    RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfo.new(
      name: "normal_workspace",
      namespace: "namespace",
      actual_state: states_module::STARTING,
      deployment_resource_version: "1"
    )
  end

  let(:abnormal_agent_info1) do
    RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfo.new(
      name: "abnormal_workspace1",
      namespace: "namespace",
      actual_state: states_module::ERROR,
      deployment_resource_version: "1"
    )
  end

  let(:abnormal_agent_info2) do
    RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfo.new(
      name: "abnormal_workspace2",
      namespace: "namespace",
      actual_state: states_module::UNKNOWN,
      deployment_resource_version: "1"
    )
  end

  let(:context) do
    {
      agent: agent,
      update_type: update_type,
      workspace_agent_infos_by_name: workspace_agent_infos_by_name,
      logger: logger
    }
  end

  subject(:returned_value) do
    described_class.observe(context)
  end

  context "when normal and abnormal workspaces exist" do
    let(:workspace_agent_infos_by_name) do
      {
        normal_workspace: normal_agent_info,
        abnormal_workspace1: abnormal_agent_info1,
        abnormal_workspace2: abnormal_agent_info2
      }
    end

    before do
      allow(logger).to receive(:debug)
      allow(logger).to receive(:warn)
    end

    it "logs normal workspaces at debug level", :unlimited_max_formatted_output_length do
      expect(logger).to receive(:debug).with(
        message: "Parsed 3 total workspace agent infos from params, " \
          "with 1 in a NORMAL actual_state and 2 in an ABNORMAL actual_state",
        agent_id: agent.id,
        update_type: update_type,
        actual_state_type: RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfosObserver::NORMAL,
        total_count: 3,
        normal_count: 1,
        abnormal_count: 2,
        normal_agent_infos: [
          {
            name: "normal_workspace",
            namespace: "namespace",
            actual_state: states_module::STARTING,
            deployment_resource_version: "1"
          }
        ],
        abnormal_agent_infos: [
          {
            name: "abnormal_workspace1",
            namespace: "namespace",
            actual_state: states_module::ERROR,
            deployment_resource_version: "1"
          },
          {
            name: "abnormal_workspace2",
            namespace: "namespace",
            actual_state: states_module::UNKNOWN,
            deployment_resource_version: "1"
          }
        ]
      )

      expect(returned_value).to be_nil
    end

    it "logs abnormal workspaces at warn level", :unlimited_max_formatted_output_length do
      expect(logger).to receive(:warn).with(
        message: "Parsed 2 workspace agent infos with an ABNORMAL actual_state from params (total: 3)",
        error_type: "abnormal_actual_state",
        agent_id: agent.id,
        update_type: update_type,
        actual_state_type: RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfosObserver::ABNORMAL,
        total_count: 3,
        normal_count: 1,
        abnormal_count: 2,
        abnormal_agent_infos: [
          {
            name: "abnormal_workspace1",
            namespace: "namespace",
            actual_state: states_module::ERROR,
            deployment_resource_version: "1"
          },
          {
            name: "abnormal_workspace2",
            namespace: "namespace",
            actual_state: states_module::UNKNOWN,
            deployment_resource_version: "1"
          }
        ]
      )

      expect(returned_value).to be_nil
    end
  end

  context "when only normal workspaces exist" do
    let(:workspace_agent_infos_by_name) do
      {
        normal_workspace: normal_agent_info
      }
    end

    it "logs normal workspaces at debug level", :unlimited_max_formatted_output_length do
      expect(logger).to receive(:debug).with(
        message: "Parsed 1 total workspace agent infos from params, " \
          "with 1 in a NORMAL actual_state and 0 in an ABNORMAL actual_state",
        agent_id: agent.id,
        update_type: update_type,
        actual_state_type: RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfosObserver::NORMAL,
        total_count: 1,
        normal_count: 1,
        abnormal_count: 0,
        normal_agent_infos: [
          {
            name: "normal_workspace",
            namespace: "namespace",
            actual_state: states_module::STARTING,
            deployment_resource_version: "1"
          }
        ],
        abnormal_agent_infos: []
      )

      expect(returned_value).to be_nil
    end
  end

  context "when only abnormal workspaces exist" do
    let(:workspace_agent_infos_by_name) do
      {
        abnormal_workspace1: abnormal_agent_info1,
        abnormal_workspace2: abnormal_agent_info2
      }
    end

    before do
      allow(logger).to receive(:debug)
      allow(logger).to receive(:warn)
    end

    it "logs zero normal workspaces at debug level", :unlimited_max_formatted_output_length do
      expect(logger).to receive(:debug).with(
        message: "Parsed 2 total workspace agent infos from params, " \
          "with 0 in a NORMAL actual_state and 2 in an ABNORMAL actual_state",
        agent_id: agent.id,
        update_type: update_type,
        actual_state_type: RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfosObserver::NORMAL,
        total_count: 2,
        normal_count: 0,
        abnormal_count: 2,
        normal_agent_infos: [],
        abnormal_agent_infos: [
          {
            name: "abnormal_workspace1",
            namespace: "namespace",
            actual_state: states_module::ERROR,
            deployment_resource_version: "1"
          },
          {
            name: "abnormal_workspace2",
            namespace: "namespace",
            actual_state: states_module::UNKNOWN,
            deployment_resource_version: "1"
          }
        ]
      )

      expect(returned_value).to be_nil
    end

    it "logs abnormal workspaces at warn level", :unlimited_max_formatted_output_length do
      expect(logger).to receive(:warn).with(
        message: "Parsed 2 workspace agent infos with an ABNORMAL actual_state from params (total: 2)",
        error_type: "abnormal_actual_state",
        agent_id: agent.id,
        update_type: update_type,
        actual_state_type: RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfosObserver::ABNORMAL,
        total_count: 2,
        normal_count: 0,
        abnormal_count: 2,
        abnormal_agent_infos: [
          {
            name: "abnormal_workspace1",
            namespace: "namespace",
            actual_state: states_module::ERROR,
            deployment_resource_version: "1"
          },
          {
            name: "abnormal_workspace2",
            namespace: "namespace",
            actual_state: states_module::UNKNOWN,
            deployment_resource_version: "1"
          }
        ]
      )

      expect(returned_value).to be_nil
    end
  end

  context "when there are no workspaces" do
    let(:workspace_agent_infos_by_name) { {} }

    it "still works" do
      expect(logger).not_to receive(:warn)

      expect(logger).to receive(:debug).with(
        message: "Parsed 0 total workspace agent infos from params, " \
          "with 0 in a NORMAL actual_state and 0 in an ABNORMAL actual_state",
        agent_id: agent.id,
        update_type: update_type,
        actual_state_type: RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfosObserver::NORMAL,
        total_count: 0,
        normal_count: 0,
        abnormal_count: 0,
        normal_agent_infos: [],
        abnormal_agent_infos: []
      )

      expect(returned_value).to be_nil
    end
  end
end
