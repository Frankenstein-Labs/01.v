# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CiProjectSubscription'], feature_category: :continuous_integration do
  it { expect(described_class.graphql_name).to eq('CiProjectSubscription') }

  specify { expect(described_class).to require_graphql_authorizations(:read_project_subscription) }

  it 'includes the ee specific fields' do
    expected_fields = %w[id downstream_project upstream_project author]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
