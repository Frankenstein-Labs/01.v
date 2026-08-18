# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Roles and permissions', feature_category: :user_management do
  let(:admin) { create(:admin) }

  before do
    sign_in(admin)
    enable_admin_mode!(admin)
    stub_licensed_features(custom_roles: true)
  end

  describe 'landing page' do
    before do
      visit admin_application_settings_roles_and_permissions_path
    end

    it 'shows a loading icon' do
      expect(page).to have_css('.gl-sr-only', text: 'Loading')
    end
  end
end
