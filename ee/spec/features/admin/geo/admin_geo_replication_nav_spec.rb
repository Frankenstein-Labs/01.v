# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin Geo Replication Nav', :js, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers
  include StubENV

  let_it_be_with_reload(:admin) { create(:admin) }
  let_it_be(:secondary_node, freeze: true) { create(:geo_node) }

  before do
    stub_licensed_features(geo: true)
    sign_in(admin)
    enable_admin_mode!(admin)
    stub_current_geo_node(secondary_node)
    stub_geo_setting(registry_replication: { enabled: true })
  end

  describe 'visit admin/geo/replication/*' do
    it 'displays the correct breadcrumbs for the project repositories page' do
      visit admin_geo_replicables_path(replicable_name_plural: 'project_repositories')

      breadcrumbs = page.all(:css, '.gl-breadcrumb-list > li')

      expect(breadcrumbs.length).to eq(3)
      expect(breadcrumbs[0].text).to eq('Admin area')
      expect(breadcrumbs[1].text).to eq('Geo sites')
      expect(breadcrumbs[2].text).to eq('Project Repositories')
    end

    it 'displays the correct breadcrumbs for the project repository details page' do
      details_path = replicable_details_admin_geo_node_path(id: secondary_node,
        replicable_name_plural: 'project_repositories',
        replicable_id: 1)

      visit details_path

      expect(page_breadcrumbs.last).to eq({ text: 'Geo::ProjectRepositoryRegistry/1', href: details_path })
    end
  end
end
