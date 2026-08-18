# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GroupSecurityPolicySource'], feature_category: :security_policy_management do
  let(:fields) { %i[namespace inherited] }

  it { expect(described_class).to have_graphql_fields(fields) }
end
