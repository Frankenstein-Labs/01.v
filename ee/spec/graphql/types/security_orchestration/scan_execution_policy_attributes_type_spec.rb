# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ScanExecutionPolicyAttributesType'], feature_category: :security_policy_management do
  include_context 'with scan execution policy specific fields'

  it { expect(described_class).to have_graphql_fields(type_specific_fields) }
end
