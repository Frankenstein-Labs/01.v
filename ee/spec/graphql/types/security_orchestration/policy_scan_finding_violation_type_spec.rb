# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyScanFindingViolation'], feature_category: :security_policy_management do
  let(:fields) { %i[name report_type severity location path] }

  it { expect(described_class).to have_graphql_fields(fields) }
end
