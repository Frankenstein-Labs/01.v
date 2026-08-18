# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::NamespaceClusterAgentMappingOperations::Delete::MappingDeleter, feature_category: :workspaces do
  include ResultMatchers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:agent) { create(:cluster_agent) }
  let(:context) { { namespace: namespace, cluster_agent: agent } }

  subject(:result) do
    described_class.delete(context)
  end

  context 'when mapping does not exist for given cluster agent and namespace' do
    it 'returns an err Result indicating that a mapping does not exist' do
      expect(result).to be_err_result(RemoteDevelopment::Messages::NamespaceClusterAgentMappingNotFound.new)
    end
  end

  context 'when mapping exists for given cluster agent and namespace' do
    let_it_be(:creator) { create(:user) }
    let_it_be(:mapping) do
      create(:namespace_cluster_agent_mapping, namespace: namespace, agent: agent, user: creator)
    end

    it 'returns an ok Result indicating that the mapping has been deleted' do
      expected = RemoteDevelopment::Messages::NamespaceClusterAgentMappingDeleteSuccessful.new({
        namespace_cluster_agent_mapping: mapping
      })
      expect(result).to be_ok_result(expected)
    end
  end
end
