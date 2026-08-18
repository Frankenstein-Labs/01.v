# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::SecurityPolicyEligibleProjectsResolver, feature_category: :security_policy_management do
  it 'has the expected arguments' do
    expect(described_class).to have_nullable_graphql_type(Types::ProjectType.connection_type)
    expect(described_class.arguments).to have_key('search')
    expect(described_class.arguments).to have_key('ids')
  end
end
