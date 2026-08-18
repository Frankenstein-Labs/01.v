# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::OrganizationClusterAgentMappingOperations::Delete::MappingDeleter, feature_category: :workspaces do
  include ResultMatchers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:agent) { create(:cluster_agent) }
  let(:context) { { organization: organization, agent: agent } }

  subject(:result) do
    described_class.delete(context)
  end

  context 'when mapping does not exist for given cluster agent and organization' do
    it 'returns an err Result indicating that a mapping does not exist' do
      expect(result).to be_err_result(RemoteDevelopment::Messages::OrganizationClusterAgentMappingNotFound.new)
    end
  end

  context 'when mapping exists for given cluster agent and organization' do
    let(:creator) { create(:user) }

    before do
      RemoteDevelopment::OrganizationClusterAgentMapping.new(
        organization_id: organization.id,
        cluster_agent_id: agent.id,
        creator_id: creator.id
      ).save!
    end

    it 'returns an ok Result indicating that the mapping has been deleted' do
      expect(result).to be_ok_result(RemoteDevelopment::Messages::OrganizationClusterAgentMappingDeleteSuccessful.new)
    end
  end
end
