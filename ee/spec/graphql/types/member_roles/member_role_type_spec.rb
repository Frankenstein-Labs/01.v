# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MemberRole'], feature_category: :system_access do
  let(:fields) do
    %w[
      baseAccessLevel description id name enabledPermissions membersCount
      dependentSecurityPolicies usersCount editPath detailsPath createdAt
    ]
  end

  specify { expect(described_class.graphql_name).to eq('MemberRole') }

  specify { expect(described_class).to have_graphql_fields(fields) }
end
