# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Catalog::AgentFlowConfigResolver, feature_category: :workflow_catalog do
  include GraphqlHelpers

  subject(:resolver) { described_class }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(
      :agent_version_id,
      :flow_config_type
    )
  end
end
