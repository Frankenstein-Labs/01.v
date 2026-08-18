# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyApproversType'], feature_category: :security_policy_management do
  let(:fields) do
    %i[users all_groups roles custom_roles]
  end

  it { expect(described_class).to have_graphql_fields(fields) }
end
