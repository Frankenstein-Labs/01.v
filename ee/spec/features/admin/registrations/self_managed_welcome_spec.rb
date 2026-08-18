# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SM welcome flow — Step 2: Set up your profile', :js, feature_category: :onboarding do
  let_it_be(:admin) { create(:admin) }

  before do
    stub_saas_features(subscriptions_trials: false)
    gitlab_sign_in(admin)
    enable_admin_mode!(admin)
  end

  context 'when arriving from Step 1 after creating a project' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }

    before do
      allow_any_instance_of(Admin::Registrations::ProfilesController) # rubocop:disable RSpec/AnyInstanceOf -- session is not accessible in JS feature specs
        .to receive(:pop_welcome_project_id).and_return(project.id)
      visit new_admin_registrations_profile_path
    end

    it 'submitting the form redirects to the created project' do
      find_by_testid('first-name').set('Jane')
      find_by_testid('last-name').set('Doe')
      find_by_testid('organization-name').set('Acme Corp')
      find_by_testid('country').find(:option, ISO3166::Country.find_country_by_alpha2('US').name).select_option
      click_button 'Continue'

      expect(page).to have_current_path(project_path(project))
    end
  end
end
