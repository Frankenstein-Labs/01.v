# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyEnforcementType'], feature_category: :security_policy_management do
  specify { expect(described_class.graphql_name).to eq('PolicyEnforcementType') }

  it 'exposes all policy enforcement types' do
    expect(described_class.values.keys).to include(*%w[ENFORCE WARN])
  end
end
