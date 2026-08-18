# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::CustomDashboards::DashboardInterface, feature_category: :custom_dashboards_foundation do
  it 'exposes the expected fields' do
    expected_fields = %i[id name description config created_at system slug]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  describe '.resolve_type' do
    subject { described_class.resolve_type(object, {}) }

    context 'for a SystemDashboard' do
      let(:object) do
        Analytics::CustomDashboards::SystemDashboard.new(slug: 'merge_requests', config: { 'title' => 'MR' })
      end

      it { is_expected.to be Types::Analytics::CustomDashboards::SystemDashboardType }
    end

    context 'for a custom Dashboard' do
      let(:object) { build_stubbed(:dashboard) }

      it { is_expected.to be Types::Analytics::CustomDashboards::DashboardType }
    end
  end
end
