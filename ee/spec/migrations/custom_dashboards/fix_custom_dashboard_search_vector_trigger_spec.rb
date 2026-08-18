# frozen_string_literal: true

require 'spec_helper'
require_migration!

RSpec.describe FixCustomDashboardSearchVectorTrigger, feature_category: :custom_dashboards_foundation do
  let(:migration) { described_class.new }

  let(:organizations) { table(:organizations) }
  let(:users) { table(:users) }
  let(:custom_dashboards) { table(:custom_dashboards) }
  let(:custom_dashboard_search_data) { table(:custom_dashboard_search_data) }

  let(:organization) { organizations.create!(name: 'Test Org', path: 'test-org') }
  let(:user) do
    users.create!(name: 'Test User', email: 'test@example.com', username: 'testuser', projects_limit: 10,
      organization_id: organization.id)
  end

  let(:valid_config) do
    {
      version: '2',
      title: 'Test Dashboard',
      description: 'Test description',
      panels: [
        {
          title: 'Test Panel',
          visualization: 'number',
          gridAttributes: { width: 4, height: 2 }
        }
      ]
    }
  end

  def create_dashboard(name:, description: '')
    custom_dashboards.create!(
      organization_id: organization.id,
      created_by_id: user.id,
      name: name,
      description: description,
      config: valid_config
    )
  end

  describe '#up' do
    before do
      migration.up
    end

    it 'syncs name and description into search_data when a dashboard is created' do
      dashboard = create_dashboard(name: 'Revenue Overview', description: 'Monthly trends')

      search_data = custom_dashboard_search_data.find_by(custom_dashboard_id: dashboard.id)

      expect(search_data.name).to eq('Revenue Overview')
      expect(search_data.description).to eq('Monthly trends')
    end

    it 'syncs name and description into search_data when a dashboard is updated' do
      dashboard = create_dashboard(name: 'Old Name', description: 'Old Description')

      dashboard.update!(name: 'New Name', description: 'New Description')

      search_data = custom_dashboard_search_data.find_by(custom_dashboard_id: dashboard.id)

      expect(search_data.name).to eq('New Name')
      expect(search_data.description).to eq('New Description')
    end

    it 'still populates search_vector' do
      dashboard = create_dashboard(name: 'Revenue Overview', description: 'Monthly trends')

      search_data = custom_dashboard_search_data.find_by(custom_dashboard_id: dashboard.id)

      expect(search_data.search_vector).to be_present
    end

    it 'handles empty description without erroring' do
      dashboard = create_dashboard(name: 'Revenue Overview', description: '')

      search_data = custom_dashboard_search_data.find_by(custom_dashboard_id: dashboard.id)

      expect(search_data.description).to eq('')
      expect(search_data.search_vector).to be_present
    end
  end

  describe '#down' do
    before do
      migration.up
      migration.down
    end

    it 'reverts to not syncing name and description' do
      dashboard = create_dashboard(name: 'Revenue Overview', description: 'Monthly trends')

      search_data = custom_dashboard_search_data.find_by(custom_dashboard_id: dashboard.id)

      expect(search_data.name).to eq('')
      expect(search_data.description).to eq('')
    end
  end
end
