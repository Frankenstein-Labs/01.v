# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin updates Security and Compliance settings', feature_category: :vulnerability_management do
  let_it_be(:admin) { create(:admin) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    sign_in(admin)
    enable_admin_mode!(admin)
    stub_licensed_features(sast: true)
  end

  describe 'Security scans settings' do
    before do
      visit security_and_compliance_admin_application_settings_path
    end

    it 'updates security scan retention period' do
      within_testid('admin-security-scans-settings') do
        fill_in 'Security scan retention period (days)', with: '45'
        click_button 'Save changes'
      end

      expect(page).to have_content 'Application settings saved successfully'
      expect(current_settings.security_scan_stale_after_days).to eq(45)
    end

    it 'validates minimum retention period' do
      within_testid('admin-security-scans-settings') do
        fill_in 'Security scan retention period (days)', with: '5'
        click_button 'Save changes'
      end

      expect(page).to have_content 'must be between 7 and 90 days'
    end

    it 'validates maximum retention period' do
      within_testid('admin-security-scans-settings') do
        fill_in 'Security scan retention period (days)', with: '100'
        click_button 'Save changes'
      end

      expect(page).to have_content 'must be between 7 and 90 days'
    end

    it 'persists the setting value after page reload' do
      within_testid('admin-security-scans-settings') do
        fill_in 'Security scan retention period (days)', with: '60'
        click_button 'Save changes'
      end

      expect(page).to have_content 'Application settings saved successfully'

      visit security_and_compliance_admin_application_settings_path

      within_testid('admin-security-scans-settings') do
        expect(find_field('Security scan retention period (days)').value).to eq('60')
      end
    end
  end

  def current_settings
    ApplicationSetting.current_without_cache
  end
end
