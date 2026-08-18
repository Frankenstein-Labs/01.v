# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin Geo Sites', :js, :geo, feature_category: :geo_replication do
  let_it_be_with_reload(:admin) { create(:admin) }

  let!(:geo_site) { create(:geo_node) }

  def expect_fields(site_fields)
    site_fields.each do |field|
      expect(page).to have_field(field)
    end
  end

  def expect_no_fields(site_fields)
    site_fields.each do |field|
      expect(page).not_to have_field(field)
    end
  end

  def expect_breadcrumb(text)
    breadcrumbs = page.all(:css, '.gl-breadcrumb-list > li')
    expect(breadcrumbs.length).to eq(3)
    expect(breadcrumbs[0].text).to eq('Admin area')
    expect(breadcrumbs[1].text).to eq('Geo Sites')
    expect(breadcrumbs[2].text).to eq(text)
  end

  before do
    allow(Gitlab::Geo).to receive(:license_allows?).and_return(true)
    sign_in(admin)
    enable_admin_mode!(admin)
  end

  describe 'index' do
    before do
      visit admin_geo_nodes_path
      wait_for_requests
    end

    it 'shows all public Geo Sites and Add site link' do
      expect(page).to have_link('Add site', href: new_admin_geo_node_path)
      page.within(find('.geo-site-core-details-grid-columns', match: :first)) do
        expect(page).to have_content(geo_site.url)
      end
    end
  end

  describe 'site form fields' do
    let(:primary_only_fields) { %w[site-reverification-interval-field] }
    let(:secondary_only_fields) { %w[site-selective-synchronization-field site-repository-capacity-field site-file-capacity-field site-object-storage-field] }

    context 'when primary' do
      before do
        geo_site.update!(primary: true)
      end

      context 'with org_mover_extend_selective_sync_to_primary_checksumming disabled' do
        before do
          stub_feature_flags(org_mover_extend_selective_sync_to_primary_checksumming: false)
        end

        it 'renders only primary fields' do
          visit edit_admin_geo_node_path(geo_site)

          expect_fields(primary_only_fields)
          expect_no_fields(secondary_only_fields)
        end
      end

      context 'with org_mover_extend_selective_sync_to_primary_checksumming enabled' do
        before do
          stub_feature_flags(org_mover_extend_selective_sync_to_primary_checksumming: true)
        end

        it 'renders the selective sync field' do
          selective_sync_field = %w[site-selective-synchronization-field]

          visit edit_admin_geo_node_path(geo_site)

          expect_fields(primary_only_fields + selective_sync_field)
        end
      end
    end

    it 'when secondary renders only secondary fields' do
      geo_site.update!(primary: false)
      visit edit_admin_geo_node_path(geo_site)

      expect_no_fields(primary_only_fields)
      expect_fields(secondary_only_fields)
    end
  end

  describe 'create a new Geo Site' do
    let(:new_ssh_key) { attributes_for(:key)[:key] }

    before do
      visit new_admin_geo_node_path
    end

    it 'creates a new Geo Site' do
      fill_in 'site-name-field', with: 'a site name'
      fill_in 'site-url-field', with: 'https://test.gitlab.com'
      click_button 'Save'

      wait_for_requests
      expect(page).to have_current_path admin_geo_nodes_path, ignore_query: true

      page.within(find('.geo-site-core-details-grid-columns', match: :first)) do
        expect(page).to have_content(geo_site.url)
      end
    end

    it 'includes Geo Sites in breadcrumbs' do
      expect_breadcrumb('Add New Site')
    end
  end

  describe 'update an existing Geo Site' do
    before do
      geo_site.update!(primary: true)

      visit edit_admin_geo_node_path(geo_site)
    end

    it 'updates an existing Geo Site' do
      fill_in 'site-url-field', with: 'http://newsite.com'
      fill_in 'site-internal-url-field', with: 'http://internal-url.com'
      click_button 'Save changes'

      wait_for_requests
      expect(page).to have_current_path admin_geo_nodes_path, ignore_query: true

      page.within(find('.geo-site-core-details-grid-columns', match: :first)) do
        expect(page).to have_content('http://newsite.com')
      end
    end

    it 'includes Geo Sites in breadcrumbs' do
      expect_breadcrumb('Edit Geo Site')
    end
  end

  describe 'remove an existing Geo Site' do
    before do
      visit admin_geo_nodes_path
      wait_for_requests
    end

    it 'removes an existing Geo Site' do
      page.click_button('Remove')

      page.within('.gl-modal') do
        page.click_button('Remove site')
      end

      expect(page).to have_current_path admin_geo_nodes_path, ignore_query: true
      wait_for_requests
      expect(page).not_to have_css('.geo-site-core-details-grid-columns')
    end
  end

  describe 'with no Geo Sites' do
    before do
      geo_site.delete
      visit admin_geo_nodes_path
      wait_for_requests
    end

    it 'hides the New Site button' do
      expect(page).not_to have_link('Add site', href: new_admin_geo_node_path)
    end

    it 'shows Discover GitLab Geo' do
      expect(page).to have_content('Discover GitLab Geo')
    end
  end

  describe 'Geo Site form routes' do
    routes = []

    before do
      routes = [{ path: new_admin_geo_node_path, slug: '/new' }, { path: edit_admin_geo_node_path(geo_site), slug: '/edit' }]
    end

    routes.each do |route|
      it "#{route.slug} renders the geo form" do
        visit route.path

        expect(page).to have_css(".geo-site-form-container")
        expect(page).not_to have_css(".js-geo-site-form")
      end
    end
  end
end
