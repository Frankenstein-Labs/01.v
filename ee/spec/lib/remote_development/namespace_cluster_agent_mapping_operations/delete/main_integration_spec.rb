# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::NamespaceClusterAgentMappingOperations::Delete::Main, feature_category: :workspaces do
  let_it_be(:namespace_cluster_agent_mapping) do
    create(:namespace_cluster_agent_mapping)
  end

  subject(:response) do
    described_class.main(
      namespace: namespace_cluster_agent_mapping.namespace,
      cluster_agent: namespace_cluster_agent_mapping.agent
    )
  end

  context 'when params are valid' do
    it 'deletes an existing mapping for a given namespace and cluster_agent' do
      expect { response }.to change { RemoteDevelopment::NamespaceClusterAgentMapping.count }.by(-1)

      expect(response.fetch(:status)).to eq(:success)
      expect(response[:message]).to be_nil
      expect(response[:payload]).not_to be_nil
      response => {
        payload: {
          namespace_cluster_agent_mapping: deleted_mapping
        }
      }

      expect(deleted_mapping).to eq(namespace_cluster_agent_mapping)
    end
  end

  context 'when params are invalid' do
    context 'when a mapping does not exist for a given namespace and cluster agent' do
      let(:namespace_cluster_agent_mapping) do
        build(:namespace_cluster_agent_mapping)
      end

      it 'does not create the mapping and returns an error' do
        expect { response }.not_to change { RemoteDevelopment::NamespaceClusterAgentMapping.count }

        expect(response).to eq({
          status: :error,
          message: "Namespace cluster agent mapping not found",
          reason: :bad_request
        })
      end
    end
  end
end
