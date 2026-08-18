# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::OrganizationClusterAgentMappingOperations::Delete::Main, feature_category: :workspaces do
  let_it_be(:organization_cluster_agent_mapping) do
    create(:organization_cluster_agent_mapping)
  end

  subject(:response) do
    described_class.main(
      organization: organization_cluster_agent_mapping.organization,
      agent: organization_cluster_agent_mapping.agent
    )
  end

  context 'when params are valid' do
    it 'deletes an existing mapping for a given organization and cluster_agent' do
      expect { response }.to change { RemoteDevelopment::OrganizationClusterAgentMapping.count }.by(-1)

      expect(response.fetch(:status)).to eq(:success)
      expect(response[:message]).to be_nil
      expect(response[:payload]).to be_empty
    end
  end

  context 'when params are invalid' do
    context 'when a mapping does not exist for a given organization and cluster agent' do
      let(:organization_cluster_agent_mapping) do
        build(:organization_cluster_agent_mapping)
      end

      it 'does not create the mapping and returns an error' do
        expect { response }.not_to change { RemoteDevelopment::OrganizationClusterAgentMapping.count }

        expect(response).to eq({
          status: :error,
          message: "Organization cluster agent mapping not found",
          reason: :bad_request
        })
      end
    end
  end
end
