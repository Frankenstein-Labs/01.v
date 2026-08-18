# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog', :js, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:project) { create(:project, :public, :in_group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let!(:agent1) do
    create(:ai_catalog_agent, :public, project_id: project.id, name: 'Agent 1', description: 'Agent Description')
  end

  before do
    enable_ai_catalog
  end

  describe 'Update existing agent' do
    before do
      sign_in(user)
      visit explore_ai_catalog_agents_path
    end

    it('navigates to Edit agent form from show page, updates values and submit') do
      click_link(agent1.name)

      expect(page).to have_content('Agent Description')
      expect(page).to have_content('Talk like a pirate!')

      click_link('Edit')

      fill_edit_form_and_submit
    end
  end

  def fill_edit_form_and_submit
    expect(page).to have_css('h1', text: "Edit agent")

    fill_in 'Display name', with: 'Updated agent name'
    fill_in 'Description', with: 'Updated agent description'
    fill_in 'System prompt', with: 'Updated system prompt'

    click_button 'Save changes'

    expect(page).to have_css('h1', text: 'Updated agent name')

    expect(page).not_to have_content('Agent Description')
    expect(page).to have_content('Updated agent description')

    expect(page).not_to have_content('Talk like a pirate!')
    expect(page).to have_content('Updated system prompt')
  end
end
