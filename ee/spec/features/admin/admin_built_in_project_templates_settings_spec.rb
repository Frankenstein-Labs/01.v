# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin updates Built-in project templates settings', feature_category: :source_code_management do
  let_it_be(:admin) { create(:admin) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    stub_licensed_features(built_in_project_templates_enabled: true)

    sign_in(admin)
    enable_admin_mode!(admin)
  end

  describe 'Built-in project templates settings' do
    before do
      visit templates_admin_application_settings_path
    end

    it 'renders the built-in project templates section' do
      within_testid('built-in-project-templates-settings') do
        expect(page).to have_content 'Built-in project templates'
      end
    end

    it 'disables built-in project templates' do
      within_testid('built-in-project-templates-settings') do
        uncheck 'Enable built-in project templates'
        click_button 'Save changes'
      end

      expect(page).to have_content 'Application settings saved successfully'
      expect(current_settings.built_in_project_templates_enabled).to be(false)
    end

    it 're-enables built-in project templates after disabling' do
      current_settings.update!(built_in_project_templates_enabled: false)
      visit templates_admin_application_settings_path

      within_testid('built-in-project-templates-settings') do
        check 'Enable built-in project templates'
        click_button 'Save changes'
      end

      expect(page).to have_content 'Application settings saved successfully'
      expect(current_settings.built_in_project_templates_enabled).to be(true)
    end

    it 'persists the setting values after page reload' do
      within_testid('built-in-project-templates-settings') do
        uncheck 'Enable built-in project templates'
        check 'Enforce for all groups'
        click_button 'Save changes'
      end

      expect(page).to have_content 'Application settings saved successfully'

      visit templates_admin_application_settings_path

      within_testid('built-in-project-templates-settings') do
        expect(find_field('Enable built-in project templates')).not_to be_checked
        expect(find_field('Enforce for all groups')).to be_checked
      end
    end

    context 'when the feature is unlicensed' do
      before do
        stub_licensed_features(built_in_project_templates_enabled: false)
        visit templates_admin_application_settings_path
      end

      it 'does not render the built-in project templates section' do
        expect(page).to have_no_testid('built-in-project-templates-settings')
      end
    end

    context 'on gitlab.com', :saas_gitlab_com_subscriptions do
      before do
        visit templates_admin_application_settings_path
      end

      it 'does not render the built-in project templates section' do
        expect(page).to have_no_testid('built-in-project-templates-settings')
      end
    end
  end

  def current_settings
    ApplicationSetting.current_without_cache
  end
end
