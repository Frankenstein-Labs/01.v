# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog', :js, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:project) { create(:project, :public, :in_group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let!(:flow1) do
    create(:ai_catalog_flow, :public, project_id: project.id, name: 'Flow 1', description: 'Flow Description')
  end

  before do
    enable_ai_catalog
  end

  describe 'Update existing flow' do
    before do
      sign_in(user)
      visit explore_ai_catalog_flows_path
    end

    it('navigates to Edit flow form from show page, updates values and submit') do
      flows = page.all('[data-testid="ai-catalog-item"]')
      expect(flows.length).to be(1)

      click_link(flow1.name)

      expect(page).to have_content('Flow Description')

      click_link('Edit')

      fill_edit_form_and_submit
    end
  end

  def fill_edit_form_and_submit
    expect(page).to have_css('h1', text: "Edit flow")

    fill_in 'Display name', with: 'Updated flow name'
    fill_in 'Description', with: 'Updated flow description'

    # Update the flow definition
    updated_flow_definition = <<~YAML
      version: v1
      environment: ambient
      components:
        - name: updated_agent
          type: AgentComponent
          prompt_id: updated_prompt
      routers: []
      flow:
        entry_point: updated_agent
    YAML

    # Definition uses a code editor component, so we need to use testid
    # TODO: Definition does not get set properly
    find_by_testid('flow-form-definition').set(updated_flow_definition)

    click_button 'Save changes'

    expect(page).to have_css('h1', text: 'Updated flow name')

    expect(page).not_to have_content('Flow Description')
    expect(page).to have_content('Updated flow description')
  end
end
