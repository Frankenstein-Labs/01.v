# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::FlowTriggersResolver, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  subject(:resolver) { described_class }

  it { expect(described_class).to require_graphql_authorizations(:manage_ai_flow_triggers) }

  it 'has expected arguments' do
    expect(described_class.arguments.keys).to contain_exactly('ids')
  end
end
