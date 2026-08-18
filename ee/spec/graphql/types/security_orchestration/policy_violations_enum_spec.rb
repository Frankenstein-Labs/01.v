# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyViolations'], feature_category: :security_policy_management do
  specify { expect(described_class.graphql_name).to eq('PolicyViolations') }

  it 'exposes all policy violations types' do
    expect(described_class.values.keys).to include(*%w[DISMISSED_IN_MR])
  end
end
