# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin updates namespace storage settings', :with_current_organization, :request_store,
  :enable_admin_mode, feature_category: :consumables_cost_management do
  include Features::SettingsHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:default_organization) { create(:organization) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    sign_in(admin)
    allow(License).to receive(:feature_available?).and_return(true)
    allow(Organizations::Organization).to receive(:default_organization).and_return(default_organization)
  end

  context 'when checking namespace plans' do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      visit namespace_storage_admin_application_settings_path
    end

    it 'saves the cost factor for forks' do
      fill_field_with_new_value _('Cost factor for forks of projects'), '0.008'

      click_button _('Save changes')

      expect(page).to have_content 'Application settings saved successfully'
      expect_field_value _('Cost factor for forks of projects'), '0.008'
    end

    it 'shows an error when the cost factor is out of range' do
      fill_field_with_new_value _('Cost factor for forks of projects'), '2.0'

      click_button _('Save changes')

      expect(page).to have_content 'Application settings update failed'
      expect(page).to have_content 'Namespace storage forks cost factor must be less than or equal to 1'
    end
  end
end
