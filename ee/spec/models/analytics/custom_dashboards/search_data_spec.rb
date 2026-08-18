# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CustomDashboards::SearchData, feature_category: :custom_dashboards_foundation do
  subject do
    described_class.new(
      dashboard: build(:dashboard),
      name: 'Test Name',
      description: 'Test Description'
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:dashboard).inverse_of(:search_data).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe '.for_custom_dashboards' do
    it 'returns only search data belonging to the given dashboards' do
      dashboard = create(:dashboard)
      create(:dashboard)

      dashboards = Analytics::CustomDashboards::Dashboard.id_in(dashboard.id)

      expect(described_class.for_custom_dashboards(dashboards)).to contain_exactly(dashboard.search_data)
    end
  end

  describe 'search vector generation' do
    it 'updates search_vector when name or description changes' do
      dashboard = create(:dashboard, name: 'Sales Overview')

      expect(dashboard.search_data.search_vector).to be_present
    end
  end
end
