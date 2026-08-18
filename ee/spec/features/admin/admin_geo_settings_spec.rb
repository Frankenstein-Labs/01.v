# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin updates Geo settings', :with_current_organization, feature_category: :geo_replication do
  let_it_be_with_reload(:admin) { create(:admin) }
  let_it_be(:default_organization, freeze: true) { create(:organization) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    sign_in(admin)
    enable_admin_mode!(admin)
    allow(License).to receive(:feature_available?).and_return(true)
    allow(Organizations::Organization).to receive(:default_organization).and_return(default_organization)
  end

  describe 'Geo settings' do
    context 'when the license has Geo feature' do
      before do
        visit admin_geo_settings_path
      end

      it 'does not show promotional empty state' do
        expect(page).not_to have_content("Available only on GitLab Premium.")
      end

      it 'renders JS form' do
        expect(page).to have_css("#js-geo-settings-form")
      end
    end

    context 'when the license does not have Geo feature' do
      before do
        allow(License).to receive(:feature_available?).and_return(false)
        visit admin_geo_settings_path
      end

      it 'shows promotional empty state' do
        expect(page).to have_content("Discover GitLab Geo")
        expect(page).to have_content("Available only on GitLab Premium.")
      end
    end
  end
end
