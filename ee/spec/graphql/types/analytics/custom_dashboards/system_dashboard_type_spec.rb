# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CustomSystemDashboard'], feature_category: :custom_dashboards_foundation do
  let(:expected_fields) do
    %i[
      id
      name
      description
      config
      created_at
      system
      slug
    ]
  end

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }
  it { is_expected.to require_graphql_authorizations(:read_system_dashboard) }

  it 'implements the CustomDashboardInterface' do
    expect(described_class.interfaces).to include(Types::Analytics::CustomDashboards::DashboardInterface)
  end
end
