# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyViolationStatus'], feature_category: :security_policy_management do
  specify { expect(described_class.graphql_name).to eq('PolicyViolationStatus') }

  it 'has a GraphQL enum value for every ScanResultPolicyViolation status' do
    model_statuses = Security::ScanResultPolicyViolation.statuses.keys

    enum_mapped_values = described_class.values.values.map { |v| v.value.to_s }

    expect(enum_mapped_values).to match_array(model_statuses)
  end
end
