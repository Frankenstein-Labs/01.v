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

  describe 'New flow' do
    before do
      sign_in(user)
      visit explore_ai_catalog_flows_path
    end

    it('navigates to New flow form, fills form and submit') do
      click_link('New flow')

      expect(page).to have_css('h1', text: 'New flow')

      select_from_listbox project.name, from: 'Select a project'
      fill_in 'Display name', with: 'New flow name'
      fill_in 'Description', with: 'New flow description'

      # Set visibility to Public (triggers confirmation modal)
      choose 'Public'
      click_button 'Make public'

      # Fill in the flow definition (YAML configuration)
      flow_definition = <<~YAML
        version: v1
        environment: ambient
        components:
          - name: main_agent
            type: AgentComponent
            prompt_id: test_prompt
        routers: []
        flow:
          entry_point: main_agent
      YAML

      # Definition uses a code editor component, so we need to use testid
      # TODO: Definition does not get set properly
      find_by_testid('flow-form-definition').set(flow_definition)

      click_button 'Create flow'

      expect(page).to have_css('h1', text: 'New flow name')
      expect(page).to have_content('New flow description')
      expect(page).to have_content('Public')
    end
  end
end
