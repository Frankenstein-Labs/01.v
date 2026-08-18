# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::OrganizationClusterAgentMappingOperations::Create::Main, feature_category: :workspaces do
  let_it_be(:creator) { create(:user) }
  let_it_be(:agent) do
    project = create(:project, organization: create(:organization))
    create(:cluster_agent, project: project)
  end

  let_it_be(:organization) { agent.project.organization }

  subject(:response) do
    described_class.main(organization: organization, agent: agent, user: creator)
  end

  context 'when params are valid' do
    it 'creates a new mapping for the given organization and cluster agent and returns success' do
      expect { response }.to change { RemoteDevelopment::OrganizationClusterAgentMapping.count }.by(1)

      expect(response.fetch(:status)).to eq(:success)
      expect(response[:message]).to be_nil
      expect(response[:payload]).not_to be_nil
      expect(response.dig(:payload, :organization_cluster_agent_mapping)).not_to be_nil

      mapping = response.dig(:payload, :organization_cluster_agent_mapping)
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect(mapping.cluster_agent_id).to eq(agent.id)
      expect(mapping.organization_id).to eq(organization.id)
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect(mapping.creator_id).to eq(creator.id)
    end
  end

  context 'when params are invalid' do
    context 'when cluster agent does not exist within the organization' do
      let(:organization) { create(:organization) }

      it 'does not create the mapping and returns an error' do
        expect { response }.not_to change { RemoteDevelopment::OrganizationClusterAgentMapping.count }

        expect(response).to eq({
          status: :error,
          message: "Organization cluster agent mapping create validation failed: " \
            "Cluster Agent's project must be within the organization",
          reason: :bad_request
        })
      end
    end

    context 'when a mapping already exists between the cluster and the organization' do
      before do
        described_class.main(organization: organization, agent: agent, user: creator)
      end

      it 'does not create the mapping and returns an error' do
        expect { response }.not_to change { RemoteDevelopment::OrganizationClusterAgentMapping.count }

        expect(response).to eq({
          status: :error,
          message: "Organization cluster agent mapping already exists",
          reason: :bad_request
        })
      end
    end
  end
end
