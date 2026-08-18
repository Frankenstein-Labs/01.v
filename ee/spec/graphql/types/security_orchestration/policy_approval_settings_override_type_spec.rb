# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyApprovalSettingsOverride'], feature_category: :security_policy_management do
  let(:fields) do
    %i[name editPath settings]
  end

  it { expect(described_class).to have_graphql_fields(fields) }
end
