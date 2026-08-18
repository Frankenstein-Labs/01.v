# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['DuoSettings'], feature_category: :"self-hosted_models" do
  it 'has specific fields' do
    expected_fields = %w[
      aiGatewayUrl aiGatewayTimeoutSeconds duoAgentPlatformServiceUrl updatedAt duoCoreFeaturesEnabled
      minimumAccessLevelExecute minimumAccessLevelExecuteAsync minimumAccessLevelManage
      minimumAccessLevelEnableOnProjects
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
