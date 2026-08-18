# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User manages pipeline cancellation restrictions', :js, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  context 'with licensed feature' do
    before do
      stub_licensed_features(ci_pipeline_cancellation_restrictions: true)
      sign_in(user)
    end

    it 'sees developer role checked by default' do
      visit project_settings_ci_cd_path(project)

      within_testid('pipeline-cancel-restrictions') do
        expect(find('#project_restrict_pipeline_cancellation_role_developer')).to be_checked
      end
    end

    it 'checks maintainer role' do
      visit project_settings_ci_cd_path(project)

      within_testid('pipeline-cancel-restrictions') do
        expect(find('#project_restrict_pipeline_cancellation_role_developer')).to be_checked

        find('#project_restrict_pipeline_cancellation_role_maintainer').click
      end

      within('#js-general-pipeline-settings') do
        click_button 'Save changes'
      end

      visit project_settings_ci_cd_path(project) # Reload from database

      expect(find('#project_restrict_pipeline_cancellation_role_maintainer')).to be_checked
      expect(find('#project_restrict_pipeline_cancellation_role_developer')).not_to be_checked
      expect(find('#project_restrict_pipeline_cancellation_role_no_one')).not_to be_checked
    end
  end

  context 'without licensed feature' do
    before do
      stub_licensed_features(ci_pipeline_cancellation_restrictions: false)
      sign_in(user)
      visit project_settings_ci_cd_path(project)
    end

    it 'does not display radio options' do
      expect(page).not_to have_selector('[data-testid="pipeline-cancel-restrictions"]')
    end
  end
end
