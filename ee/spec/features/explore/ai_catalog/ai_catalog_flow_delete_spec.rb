# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog Flow Delete', :js, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:project) { create(:project, :public, :in_group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let!(:flow1) do
    create(:ai_catalog_flow, :public, project_id: project.id, name: 'Flow 1', description: 'Flow Description')
  end

  before do
    enable_ai_catalog
  end

  describe 'Delete existing flow' do
    let!(:flow_to_delete) do
      create(:ai_catalog_flow, :public, project_id: project.id, name: 'Flow to Delete',
        description: 'Will be deleted')
    end

    context 'when user is a maintainer' do
      before do
        sign_in(user)
        visit explore_ai_catalog_flows_path
      end

      it('deletes flow via dropdown menu and confirms in modal') do
        flows = page.all('[data-testid="ai-catalog-item"]')
        expect(flows.length).to be(2)

        click_link(flow_to_delete.name)
        wait_for_requests
        expect(page).to have_content('Will be deleted')

        click_more_actions_button 'Hide'

        expect(page).to have_content('Hide flow')
        expect(page).to have_content('Are you sure you want to hide flow Flow to Delete?')

        within('.gl-modal') do
          click_button 'Confirm'
        end

        wait_for_requests

        expect(page).to have_current_path(%r{/explore/ai-catalog}, ignore_query: true)

        # Navigate back to Flows tab to verify deletion
        page.within('.gl-tabs') do
          click_link('Flows')
        end

        # Verify the deleted flow is removed, but flow1 remains
        flows = page.all('[data-testid="ai-catalog-item"]')
        expect(flows.length).to be(1)
        expect(page).to have_content('Flow 1')
        expect(page).not_to have_content('Flow to Delete')
      end
    end

    context 'when user is an instance admin' do
      let_it_be(:admin) { create(:admin) }

      before do
        sign_in(admin)
        enable_admin_mode!(admin)
        visit explore_ai_catalog_flows_path
      end

      it('can soft delete (hide) flow from catalog') do
        click_link(flow_to_delete.name)
        wait_for_requests

        click_more_actions_button 'Delete'

        expect(page).to have_content('Delete flow')
        expect(page).to have_content('Deletion method')

        within('.gl-modal') do
          # Select soft delete option
          choose 'Hide from the AI Catalog'
          click_button 'Confirm'
        end

        wait_for_requests

        # Flow should be hidden from catalog but not permanently deleted
        expect(page).to have_current_path(%r{/explore/ai-catalog}, ignore_query: true)

        page.within('.gl-tabs') do
          click_link('Flows')
        end

        flows = page.all('[data-testid="ai-catalog-item"]')
        expect(flows.length).to be(1)
      end

      it('can hard delete (permanently delete) flow') do
        click_link(flow_to_delete.name)
        wait_for_requests

        click_more_actions_button 'Delete'

        expect(page).to have_content('Delete flow')

        within('.gl-modal') do
          # Select hard delete option (default)
          choose 'Delete permanently'
          click_button 'Confirm'
        end

        wait_for_requests

        # Flow should be permanently deleted
        expect(page).to have_current_path(%r{/explore/ai-catalog}, ignore_query: true)

        page.within('.gl-tabs') do
          click_link('Flows')
        end

        flows = page.all('[data-testid="ai-catalog-item"]')
        expect(flows.length).to be(1)
        expect(page).not_to have_content('Flow to Delete')
      end
    end

    context 'when user is a developer' do
      let_it_be(:developer) { create(:user) }

      before_all do
        project.add_developer(developer)
      end

      before do
        sign_in(developer)
        visit explore_ai_catalog_flows_path
      end

      it('does not show delete button in dropdown') do
        click_link(flow_to_delete.name)
        wait_for_requests

        click_more_actions_dropdown
        expect(page).not_to have_css('[data-testid="delete-button"]')
      end
    end
  end
end
