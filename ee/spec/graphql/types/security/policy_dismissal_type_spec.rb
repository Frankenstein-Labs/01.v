# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::PolicyDismissalType, feature_category: :security_policy_management do
  let(:fields) { %i[id security_policy] }

  it { expect(described_class).to have_graphql_fields(fields) }
  it { expect(described_class).to require_graphql_authorizations(:read_security_resource) }
end
