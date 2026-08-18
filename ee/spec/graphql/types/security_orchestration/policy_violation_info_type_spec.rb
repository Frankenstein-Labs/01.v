# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyViolationInfo'], feature_category: :security_policy_management do
  let(:fields) { %i[name report_type status enforcement_type security_policy_id dismissed] }

  it { expect(described_class).to have_graphql_fields(fields) }
end
