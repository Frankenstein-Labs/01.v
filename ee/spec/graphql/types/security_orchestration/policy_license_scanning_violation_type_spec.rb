# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyLicenseScanningViolation'], feature_category: :security_policy_management do
  let(:fields) { %i[license dependencies url] }

  it { expect(described_class).to have_graphql_fields(fields) }
end
