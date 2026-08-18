# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::OrganizationClusterAgentMappingOperations::Create::ClusterAgentValidator, feature_category: :workspaces do
  include ResultMatchers

  let(:agent) { create(:cluster_agent) }
  let(:context) { { agent: agent, organization: organization } }

  subject(:result) do
    described_class.validate(context)
  end

  context 'when cluster exists in the organization' do
    let(:organization) { agent.project.organization }

    it 'returns an ok Result containing the original values that were passed' do
      expect(result).to eq(Gitlab::Fp::Result.ok(context))
    end
  end

  context 'when cluster agent does not exist in the organization' do
    let(:organization) { create(:organization) }

    it 'returns an err Result containing a validation error' do
      expect(result).to be_err_result(
        RemoteDevelopment::Messages::OrganizationClusterAgentMappingCreateValidationFailed.new({
          details: "Cluster Agent's project must be within the organization"
        }))
    end
  end
end
