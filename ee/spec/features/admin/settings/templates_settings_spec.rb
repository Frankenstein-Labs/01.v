# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin updates templates settings', :with_current_organization, :request_store, :enable_admin_mode,
  feature_category: :importers do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:default_organization) { create(:organization) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    sign_in(admin)
    allow(License).to receive(:feature_available?).and_return(true)
    allow(Organizations::Organization).to receive(:default_organization).and_return(default_organization)
    visit templates_admin_application_settings_path
  end

  it 'render "Templates" section' do
    within_testid('templates-settings') do
      expect(page).to have_content 'Templates'
    end
  end

  it 'render "Custom project templates" section' do
    within_testid('custom-project-template-container') do
      expect(page).to have_content 'Custom project templates'
    end
  end
end
