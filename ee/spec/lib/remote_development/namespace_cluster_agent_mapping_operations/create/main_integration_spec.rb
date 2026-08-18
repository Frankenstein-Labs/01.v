# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::NamespaceClusterAgentMappingOperations::Create::Main, feature_category: :workspaces do
  let_it_be(:creator) { create(:user) }
  # NOTE: reload is necessary to calculate traversal IDs
  let_it_be_with_reload(:cluster_agent) do
    project_in_group = create(:project, :in_group)
    create(:cluster_agent, project: project_in_group)
  end

  let_it_be(:namespace) { cluster_agent.project.group }

  subject(:response) do
    described_class.main(namespace: namespace, cluster_agent: cluster_agent, user: creator)
  end

  context 'when params are valid' do
    it 'creates a new mapping for the given namespace and cluster agent and returns success' do
      expect { response }.to change { RemoteDevelopment::NamespaceClusterAgentMapping.count }.by(1)

      expect(response.fetch(:status)).to eq(:success)
      expect(response[:message]).to be_nil
      expect(response[:payload]).not_to be_nil
      response => {
        payload: {
          namespace_cluster_agent_mapping: mapping
        }
      }

      expect(mapping).not_to be_nil
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect(mapping.cluster_agent_id).to eq(cluster_agent.id)
      expect(mapping.namespace_id).to eq(namespace.id)
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect(mapping.creator_id).to eq(creator.id)
    end
  end

  context 'when params are invalid' do
    context 'when cluster agent does not exist within the namespace' do
      let(:cluster_agent) { create(:cluster_agent) }

      it 'does not create the mapping and returns an error' do
        expect { response }.not_to change { RemoteDevelopment::NamespaceClusterAgentMapping.count }

        expect(response).to eq({
          status: :error,
          message: "Namespace cluster agent mapping create validation failed: " \
            "Cluster Agent's project must be nested within the namespace",
          reason: :bad_request
        })
      end
    end

    context 'when a mapping already exists between the cluster and the namespace' do
      before do
        described_class.main(namespace: namespace, cluster_agent: cluster_agent, user: creator)
      end

      it 'does not create the mapping and returns an error' do
        expect { response }.not_to change { RemoteDevelopment::NamespaceClusterAgentMapping.count }

        expect(response).to eq({
          status: :error,
          message: "Namespace cluster agent mapping already exists",
          reason: :bad_request
        })
      end
    end
  end
end
