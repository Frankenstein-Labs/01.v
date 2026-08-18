# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::NamespaceClusterAgentMappingOperations::Create::ClusterAgentValidator, feature_category: :workspaces do
  include ResultMatchers

  # NOTE: reload is necessary to calculate traversal IDs
  let_it_be_with_reload(:cluster_agent) { create(:cluster_agent, project: create(:project, :in_group)) }

  let(:context) { { namespace: namespace, cluster_agent: cluster_agent } }

  subject(:result) do
    described_class.validate(context)
  end

  context 'when cluster exists in the group' do
    let_it_be(:namespace) { cluster_agent.project.group }

    it 'returns an ok Result containing the original values that were passed' do
      expect(result).to eq(Gitlab::Fp::Result.ok(context))
    end
  end

  context 'when cluster agent does not exist in the group' do
    let_it_be(:namespace) { create(:group) }

    it 'returns an err Result containing a validation error' do
      expect(result).to be_err_result(
        RemoteDevelopment::Messages::NamespaceClusterAgentMappingCreateValidationFailed.new({
          details: "Cluster Agent's project must be nested within the namespace"
        }))
    end
  end
end
