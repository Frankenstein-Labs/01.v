# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfo, feature_category: :workspaces do
  include_context "with constant modules"

  let(:agent_info_constructor_args) do
    {
      name: 'name',
      namespace: 'namespace',
      actual_state: states_module::RUNNING,
      deployment_resource_version: '1'
    }
  end

  let(:other) { described_class.new(**agent_info_constructor_args) }

  subject(:agent_info_instance) do
    described_class.new(**agent_info_constructor_args)
  end

  describe '#==' do
    context 'when objects are equal' do
      it 'returns true' do
        expect(agent_info_instance).to eq(other)
      end
    end

    context 'when objects are not equal' do
      it 'returns false' do
        other.instance_variable_set(:@name, 'other_name')
        expect(agent_info_instance).not_to eq(other)
      end
    end
  end
end
