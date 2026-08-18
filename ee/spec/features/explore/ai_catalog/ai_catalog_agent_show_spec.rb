# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog Agent Show', :js, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:foundational_agents_count) { Ai::FoundationalChatAgent.where(public: true).count }

  let_it_be(:project) { create(:project, :public, :in_group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let!(:agent1) do
    create(:ai_catalog_agent, :public, project_id: project.id, name: 'Agent 1', description: 'Agent Description')
  end

  before do
    enable_ai_catalog
  end

  describe 'Delete existing agent' do
    let!(:agent_to_delete) do
      create(:ai_catalog_agent, :public, project_id: project.id, name: 'Agent to Delete',
        description: 'Will be deleted')
    end

    context 'when user is a maintainer' do
      before do
        sign_in(user)
        visit explore_ai_catalog_agents_path
      end

      it('deletes agent via dropdown menu and confirms in modal') do
        agents = page.all('[data-testid="ai-catalog-item"]')
        expect(agents.length).to be(foundational_agents_count + 2)

        click_link(agent_to_delete.name)
        wait_for_requests
        expect(page).to have_content('Will be deleted')

        click_more_actions_button 'Hide'

        expect(page).to have_content('Hide agent')
        expect(page).to have_content('Are you sure you want to hide agent Agent to Delete?')

        within('.gl-modal') do
          click_button 'Confirm'
        end

        wait_for_requests

        expect(page).to have_current_path(%r{/explore/ai-catalog}, ignore_query: true)

        # Verify the deleted agent is removed, but agent1 remains
        agents = page.all('[data-testid="ai-catalog-item"]')
        expect(agents.length).to be(foundational_agents_count + 1)
        expect(page).to have_content('Agent 1')
        expect(page).not_to have_content('Agent to Delete')
      end
    end

    context 'when user is an instance admin' do
      let_it_be(:admin) { create(:admin) }

      before do
        sign_in(admin)
        enable_admin_mode!(admin)
        visit explore_ai_catalog_agents_path
      end

      it('can soft delete (hide) agent from catalog') do
        click_link(agent_to_delete.name)
        wait_for_requests

        click_more_actions_button 'Delete'

        expect(page).to have_content('Delete agent')
        expect(page).to have_content('Deletion method')

        within('.gl-modal') do
          # Select soft delete option
          choose 'Hide from the AI Catalog'
          click_button 'Confirm'
        end

        wait_for_requests

        # Agent should be hidden from catalog but not permanently deleted
        expect(page).to have_current_path(%r{/explore/ai-catalog}, ignore_query: true)
        agents = page.all('[data-testid="ai-catalog-item"]')
        expect(agents.length).to be(foundational_agents_count + 1)
      end

      it('can hard delete (permanently delete) agent') do
        click_link(agent_to_delete.name)
        wait_for_requests

        click_more_actions_button 'Delete'

        expect(page).to have_content('Delete agent')

        within('.gl-modal') do
          # Select hard delete option (default)
          choose 'Delete permanently'
          click_button 'Confirm'
        end

        wait_for_requests

        # Agent should be permanently deleted
        expect(page).to have_current_path(%r{/explore/ai-catalog}, ignore_query: true)
        agents = page.all('[data-testid="ai-catalog-item"]')
        expect(agents.length).to be(foundational_agents_count + 1)
        expect(page).not_to have_content('Agent to Delete')
      end
    end

    context 'when user is a developer' do
      let_it_be(:developer) { create(:user) }

      before_all do
        project.add_developer(developer)
      end

      before do
        sign_in(developer)
        visit explore_ai_catalog_agents_path
      end

      it('does not show delete button in dropdown') do
        click_link(agent_to_delete.name)
        wait_for_requests

        click_more_actions_dropdown
        expect(page).not_to have_button('Delete')
      end
    end
  end
end
