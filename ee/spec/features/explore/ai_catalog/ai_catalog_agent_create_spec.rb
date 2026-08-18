# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog', :js, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include ListboxHelpers

  let_it_be(:project) { create(:project, :public, :in_group, :with_duo_features_enabled) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  before do
    enable_ai_catalog
  end

  describe 'New agent' do
    before do
      sign_in(user)
      visit explore_ai_catalog_agents_path
    end

    it('navigates to New agent form, fills form and submit') do
      click_link('New agent')

      expect(page).to have_css('h1', text: 'New agent')

      select_from_listbox project.name, from: 'Select a project'
      fill_in 'Display name', with: 'New agent name'
      fill_in 'Description', with: 'New agent description'
      fill_in 'System prompt', with: 'New system prompt'

      click_button 'Create agent'

      expect(page).to have_css('h1', text: 'New agent name')
      expect(page).to have_content('New agent description')
      expect(page).to have_content('New system prompt')
    end
  end
end
