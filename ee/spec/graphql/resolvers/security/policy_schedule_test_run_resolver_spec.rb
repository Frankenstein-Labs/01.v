# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::PolicyScheduleTestRunResolver, feature_category: :security_policy_management do
  include GraphqlHelpers

  it 'has the correct nullable graphql type' do
    expect(described_class).to have_nullable_graphql_type(
      Types::Security::PolicyScheduleTestRunType
    )
  end

  it 'accepts the expected arguments' do
    expect(described_class).to have_graphql_arguments(:id)
  end
end
