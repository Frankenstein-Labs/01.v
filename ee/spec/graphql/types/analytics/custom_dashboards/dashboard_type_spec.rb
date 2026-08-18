# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CustomDashboard'], feature_category: :custom_dashboards_foundation do
  let(:expected_fields) do
    %i[
      id
      name
      description
      config
      created_at
      system
      slug
      organization
      namespace
      project
      created_by
      updated_by
      updated_at
      lock_version
    ]
  end

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
  it { is_expected.to require_graphql_authorizations(:read_custom_dashboard) }

  it 'implements the CustomDashboardInterface' do
    expect(described_class.interfaces).to include(Types::Analytics::CustomDashboards::DashboardInterface)
  end
end
