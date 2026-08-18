# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::NamespaceClusterAgentMappingOperations::Validations, feature_category: :workspaces do
  describe 'filter_valid_namespace_cluster_agent_mappings' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:root_agent) { create(:cluster_agent) }
    let_it_be_with_reload(:nested_agent) { create(:cluster_agent) }
    let_it_be_with_reload(:root_namespace) do
      create(:group,
        projects: [root_agent.project],
        children: [
          create(:group,
            projects: [nested_agent.project]
          )
        ]
      )
    end

    let(:namespace) { root_namespace }
    let(:namespace_cluster_agent_mappings) do
      [
        build_stubbed(
          :namespace_cluster_agent_mapping,
          user: user,
          namespace: namespace,
          agent: root_agent
        ),
        build_stubbed(
          :namespace_cluster_agent_mapping,
          user: user,
          namespace: namespace,
          agent: nested_agent
        )
      ]
    end

    subject(:response) do
      described_class.filter_valid_namespace_cluster_agent_mappings(
        namespace_cluster_agent_mappings: namespace_cluster_agent_mappings
      )
    end

    context 'when cluster agents exist within the namespace' do
      it 'returns all cluster agents passed in the parameters' do
        expect(response).to eq(namespace_cluster_agent_mappings)
      end
    end

    context 'when a cluster agent does not exist within the mapped namespace' do
      # With this, all namespace-agent mappings will be bound to the nested namespace.
      # As such, one of the mappings will be between the nested namespace and the root agent which is considered
      # invalid and should be excluded from the results
      let(:namespace) { root_namespace.children.first }

      it 'returns cluster agents excluding those that do not reside in the namespace' do
        mappings_with_nested_agent = namespace_cluster_agent_mappings.filter do |mapping|
          mapping.agent == nested_agent
        end

        expect(response).to eq(mappings_with_nested_agent)
      end
    end

    context 'when a non-existent cluster agent is passed in the parameters' do
      let(:nested_agent) { build_stubbed(:cluster_agent) }

      it 'returns cluster agents excluding those are non-existent' do
        mappings_without_nested_agent = namespace_cluster_agent_mappings.filter do |mapping|
          mapping.agent != nested_agent
        end

        expect(response).to eq(mappings_without_nested_agent)
      end
    end

    context 'when an empty list of agents is passed in the parameters' do
      let(:namespace_cluster_agent_mappings) { [] }

      it 'returns an empty array' do
        expect(response).to eq([])
      end
    end
  end
end
