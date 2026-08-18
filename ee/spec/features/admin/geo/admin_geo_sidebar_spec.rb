# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin Geo Sidebar', :js, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers
  include StubENV

  let_it_be_with_reload(:admin) { create(:admin) }
  let_it_be(:primary_node, freeze: true) { create(:geo_node, :primary) }

  before do
    allow(admin).to receive(:can_admin_all_resources?).and_return(true)
    stub_licensed_features(geo: true)
    stub_current_geo_node(primary_node)
    sign_in(admin)
    enable_admin_mode!(admin)
  end

  shared_examples 'active sidebar link' do |link_name|
    before do
      visit path
      wait_for_requests
    end

    it 'has active class' do
      within_testid('super-sidebar') do
        expect(page).to have_css('a[aria-current="page"]', text: link_name)
      end
    end
  end

  describe 'visiting geo sites' do
    it_behaves_like 'active sidebar link', 'Sites' do
      let(:path) { admin_geo_nodes_path }
    end
  end

  describe 'visiting geo settings' do
    before do
      stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    end

    it_behaves_like 'active sidebar link', 'Settings' do
      let(:path) { admin_geo_settings_path }
    end
  end

  context 'on secondary' do
    before do
      stub_secondary_node
    end

    describe 'visiting geo replicables',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/8638' do
      Gitlab::Geo.replication_enabled_replicator_classes.each do |replicator_class|
        it_behaves_like 'active sidebar link', 'Sites' do
          let(:path) { admin_geo_replicables_path(replicable_name_plural: replicator_class.replicable_name_plural) }
        end
      end
    end
  end
end
