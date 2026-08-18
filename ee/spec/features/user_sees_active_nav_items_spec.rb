# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User sees correct active nav items in the super sidebar', :js, feature_category: :value_stream_management do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: current_user) }
  let_it_be(:project) { create(:project, group: group) }

  before do
    sign_in(current_user)
  end

  context 'when visiting a project\'s API Fuzzing configuration' do
    before do
      stub_licensed_features(security_dashboard: true)
      stub_request(:get, /gitlab-api-fuzzing-config\.yml$/).to_return(status: 200)
      visit project_security_configuration_api_fuzzing_path(project)
    end

    it 'renders the side navigation with the correct submenu set as active' do
      expect(page).to have_active_navigation('Secure')
      expect(page).to have_active_sub_navigation('Security configuration')
    end
  end

  context 'when visiting a project\'s Dependency list' do
    before do
      stub_licensed_features(dependency_scanning: true, license_scanning: true, security_dashboard: true)
      visit project_dependencies_path(project)
    end

    it 'renders the side navigation with the correct submenu set as active' do
      expect(page).to have_active_navigation('Secure')
      expect(page).to have_active_sub_navigation('Dependency list')
    end
  end

  context 'when visiting a project\'s SAST configuration' do
    before do
      stub_licensed_features(security_dashboard: true)
      visit project_security_configuration_sast_path(project)
    end

    it 'renders the side navigation with the correct submenu set as active' do
      expect(page).to have_active_navigation('Secure')
      expect(page).to have_active_sub_navigation('Security configuration')
    end
  end
end
