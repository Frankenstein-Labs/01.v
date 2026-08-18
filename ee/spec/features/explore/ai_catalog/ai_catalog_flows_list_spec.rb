# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog', :js, :with_current_organization, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :in_group) }

  before do
    enable_ai_catalog
  end

  describe 'Flows' do
    before do
      sign_in(user)
      visit explore_ai_catalog_flows_path
    end

    it('displays tabs') do
      page.within('.gl-tabs') do
        expect(page).to have_link('Agents')
        expect(page).to have_link('Flows')
      end
    end

    it 'displays an empty list of flows' do
      expect(page).to have_content('Get started with the AI Catalog')
      expect(page).to have_content('Build agents and flows to automate tasks and solve complex problems.')

      flows = page.all('[data-testid="ai-catalog-item"]')
      expect(flows.length).to be(0)
    end

    context 'when there are existing flows' do
      # Two-project setup to test cross-project visibility permissions:
      # - project: user will become maintainer in nested context
      # - other_project: user is NOT maintainer
      let_it_be(:other_project) { create(:project, :public, :in_group) }

      # Public flows - visible to everyone regardless of project permissions
      let_it_be(:flow1) { create(:ai_catalog_flow, :public, project_id: project.id, name: 'Flow 1') }
      let_it_be(:flow2) { create(:ai_catalog_flow, :public, project_id: other_project.id, name: 'Flow 2') }
      let_it_be(:flow3) { create(:ai_catalog_flow, :public, project_id: other_project.id, name: 'Flow 3') }

      # Private flows - visibility depends on project maintainer permissions
      # User should see flow4 & flow5 only when they're maintainer of project
      # User should NOT see flow6 (from other_project where they're not maintainer)
      let_it_be(:flow4) { create(:ai_catalog_flow, project_id: project.id, name: 'Flow 4') }
      let_it_be(:flow5) { create(:ai_catalog_flow, project_id: project.id, name: 'Flow 5') }
      let_it_be(:flow6) { create(:ai_catalog_flow, project_id: other_project.id, name: 'Flow 6') }

      let_it_be(:agent1) { create(:ai_catalog_agent, :public, project_id: project.id, name: 'Agent 1') }
      let_it_be(:agent2) { create(:ai_catalog_agent, :public, project_id: project.id, name: 'Agent 2') }

      it 'displays only public flows when user has no maintainer permissions' do
        flows = page.all('[data-testid="ai-catalog-item"]')
        expect(flows.length).to be(3)

        # Verify all public flows are displayed (from any project)
        expect(page).to have_content('Flow 1')
        expect(page).to have_content('Flow 2')
        expect(page).to have_content('Flow 3')

        # Verify no private flows are displayed
        expect(page).not_to have_content('Flow 4')
        expect(page).not_to have_content('Flow 5')
        expect(page).not_to have_content('Flow 6')
      end

      it 'displays only flows in the Flows tab, not agents' do
        flows = page.all('[data-testid="ai-catalog-item"]')
        expect(flows.length).to be(3)

        # Verify flow names are displayed
        expect(page).to have_content('Flow 1')
        expect(page).to have_content('Flow 2')
        expect(page).to have_content('Flow 3')

        # Verify agents are not displayed in Flows tab
        expect(page).not_to have_content('Agent 1')
        expect(page).not_to have_content('Agent 2')
      end

      context 'when user is maintainer of one project' do
        before_all do
          project.add_maintainer(user)
        end

        it 'displays all public flows and private flows only from projects user maintains' do
          flows = page.all('[data-testid="ai-catalog-item"]')
          expect(flows.length).to be(5)

          # Verify all public flows are displayed (from any project)
          expect(page).to have_content('Flow 1')  # public, project
          expect(page).to have_content('Flow 2')  # public, other_project
          expect(page).to have_content('Flow 3')  # public, other_project

          # Verify private flows from project where user is maintainer
          expect(page).to have_content('Flow 4')  # private, project
          expect(page).to have_content('Flow 5')  # private, project

          # Verify private flows from other projects are NOT displayed
          expect(page).not_to have_content('Flow 6') # private, other_project
        end
      end
    end
  end
end
