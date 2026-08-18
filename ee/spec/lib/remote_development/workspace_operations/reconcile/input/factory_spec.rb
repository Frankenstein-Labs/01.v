# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Input::Factory, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:agent) { instance_double("Clusters::Agent", id: 1) } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  let(:user) { instance_double("User", name: "name", email: "name@example.com") } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  let(:workspace) { create(:workspace) }
  let(:namespace) { workspace.namespace }

  let(:workspace_agent_info_hash) do
    create_workspace_agent_info_hash(
      workspace: workspace,
      previous_actual_state: previous_actual_state,
      current_actual_state: current_actual_state,
      workspace_exists: false,
      workspace_variables_environment: {},
      workspace_variables_file: {}
    )
  end

  let(:expected_namespace) { workspace.namespace }
  let(:expected_deployment_resource_version) { "1" }

  let(:expected_agent_info) do
    ::RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfo.new(
      name: workspace.name,
      namespace: expected_namespace,
      actual_state: current_actual_state,
      deployment_resource_version: expected_deployment_resource_version
    )
  end

  subject(:built_agent_info) do
    described_class.build(agent_info_hash_from_params: workspace_agent_info_hash)
  end

  before do
    # rubocop:todo Layout/LineLength -- this line will not be too long once we rename RemoteDevelopment namespace to Workspaces
    allow_next_instance_of(RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ActualStateCalculator) do |instance|
      # rubocop:enable Layout/LineLength
      # rubocop:disable RSpec/ExpectInHook -- we want to assert expectations on this mock, otherwise we'd just have to duplicate the assertions
      expect(instance).to receive(:calculate_actual_state).with(
        latest_k8s_deployment_info: workspace_agent_info_hash[:latest_k8s_deployment_info],
        termination_progress: termination_progress,
        latest_error_details: nil
      ) { current_actual_state }
      # rubocop:enable RSpec/ExpectInHook
    end
  end

  describe '#build' do
    context 'when current actual state is not Terminated or Unknown' do
      let(:previous_actual_state) { states_module::STARTING }
      let(:current_actual_state) { states_module::RUNNING }
      let(:termination_progress) { nil }

      it 'returns an AgentInfo object with namespace and deployment_resource_version populated' do
        expect(built_agent_info).to eq(expected_agent_info)
      end
    end

    context 'when current actual state is Terminating' do
      let(:previous_actual_state) { states_module::RUNNING }
      let(:current_actual_state) { states_module::TERMINATING }
      let(:expected_deployment_resource_version) { nil }
      let(:termination_progress) do
        RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ActualStateCalculator::TERMINATING
      end

      it 'returns an AgentInfo object without deployment_resource_version populated' do
        expect(built_agent_info).to eq(expected_agent_info)
      end
    end

    context 'when current actual state is Terminated' do
      let(:previous_actual_state) { states_module::TERMINATING }
      let(:current_actual_state) { states_module::TERMINATED }
      let(:expected_deployment_resource_version) { nil }
      let(:termination_progress) do
        RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ActualStateCalculator::TERMINATED
      end

      it 'returns an AgentInfo object without deployment_resource_version populated' do
        expect(built_agent_info).to eq(expected_agent_info)
      end
    end

    # TODO: Should this case even be possible? See
    # - https://gitlab.com/gitlab-org/gitlab/-/merge_requests/126127#note_1492911475
    # - https://gitlab.com/gitlab-org/gitlab/-/issues/420709
    context "when namespace is missing in the payload" do
      let(:previous_actual_state) { states_module::STARTING }
      let(:current_actual_state) { states_module::RUNNING }
      let(:termination_progress) { nil }
      let(:namespace) { nil }
      let(:expected_namespace) { nil }

      before do
        allow(workspace).to receive(:namespace).and_return(nil)
      end

      it 'returns an AgentInfo object without namespace populated' do
        expect(built_agent_info).to eq(expected_agent_info)
      end
    end
  end
end
