# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin updates CI/CD settings', :with_current_organization, :request_store, :enable_admin_mode,
  feature_category: :pipeline_composition do
  include Features::SettingsHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:default_organization) { create(:organization) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    sign_in(admin)
    allow(License).to receive(:feature_available?).and_return(true)
    allow(Organizations::Organization).to receive(:default_organization).and_return(default_organization)
    visit ci_cd_admin_application_settings_path
  end

  describe 'CI/CD Catalog settings' do
    it 'changes CI/CD Catalog projects allowlist' do
      within_testid('catalog-settings') do
        fill_field_with_new_value s_('AdminSettings|CI/CD Catalog publishing allowlist'),
          "gitlab-org/project1\ngitlab-org/.*"

        expect_save_settings

        expect_field_value s_('AdminSettings|CI/CD Catalog publishing allowlist'),
          "gitlab-org/project1\ngitlab-org/.*"
      end
    end
  end

  describe 'package registry settings', feature_category: :package_registry do
    it 'changes package forwarding and enforcement settings', :aggregate_failures do
      within_testid('forward-package-requests-form') do
        click_checked_field format(s_('PackageRegistry|Forward %{package_type} package requests'),
          package_type: 'Maven')
        click_unchecked_field format(s_('PackageRegistry|Enforce %{package_type} setting for all subgroups'),
          package_type: 'Maven')
        click_checked_field format(s_('PackageRegistry|Forward %{package_type} package requests'),
          package_type: 'npm')
        click_unchecked_field format(s_('PackageRegistry|Enforce %{package_type} setting for all subgroups'),
          package_type: 'npm')
        click_checked_field format(s_('PackageRegistry|Forward %{package_type} package requests'),
          package_type: 'PyPI')
        click_unchecked_field format(s_('PackageRegistry|Enforce %{package_type} setting for all subgroups'),
          package_type: 'PyPI')

        expect_save_settings

        expect_field_unchecked format(s_('PackageRegistry|Forward %{package_type} package requests'),
          package_type: 'Maven')
        expect_field_checked format(s_('PackageRegistry|Enforce %{package_type} setting for all subgroups'),
          package_type: 'Maven')
        expect_field_unchecked format(s_('PackageRegistry|Forward %{package_type} package requests'),
          package_type: 'npm')
        expect_field_checked format(s_('PackageRegistry|Enforce %{package_type} setting for all subgroups'),
          package_type: 'npm')
        expect_field_unchecked format(s_('PackageRegistry|Forward %{package_type} package requests'),
          package_type: 'PyPI')
        expect_field_checked format(s_('PackageRegistry|Enforce %{package_type} setting for all subgroups'),
          package_type: 'PyPI')
      end
    end
  end

  context 'with virtual registries settings', feature_category: :virtual_registry do
    let(:dependency_proxy_feature_enabled) { true }

    before do
      stub_config(dependency_proxy: { enabled: dependency_proxy_feature_enabled })
      visit ci_cd_admin_application_settings_path
    end

    it 'allows you to change the virtual_registries_endpoints_api_limit setting' do
      within_testid('virtual-registries-form') do
        fill_field_with_new_value s_('VirtualRegistries|API endpoints rate limit'), '500'

        expect_save_settings

        expect_field_value s_('VirtualRegistries|API endpoints rate limit'), '500'
      end
    end

    context 'when dependency_proxy feature is disabled' do
      let(:dependency_proxy_feature_enabled) { false }

      it 'does not display the virtual registry settings' do
        expect(page).not_to have_selector('[data-testid="virtual-registries-form"]')
      end
    end
  end
end
