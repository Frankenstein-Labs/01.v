# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group Workspaces Settings', :js, feature_category: :workspaces do
  include WaitForRequests

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) do
    create(:project, :public, :in_group, :custom_repo, path: 'test-project', namespace: group)
  end

  let_it_be(:agent) do
    create(:ee_cluster_agent, :with_existing_workspaces_agent_config, project: project, created_by_user: user)
  end

  before_all do
    group.add_owner(user)
  end

  include_context 'with kubernetes agent service'

  before do
    stub_licensed_features(remote_development: true)
    sign_in(user)
    visit group_settings_workspaces_path(group)
    wait_for_requests
  end

  describe 'Group agents' do
    context 'when there are not available agents' do
      it 'displays available agents table with empty state message' do
        expect(page).to have_content 'This group has no available agents.'
      end
    end

    context 'when there are mapped agents' do
      let_it_be(:cluster_agent_mapping) do
        create(
          :namespace_cluster_agent_mapping,
          user: user, agent: agent,
          namespace: group
        )
      end

      it 'displays agent in the agents table' do
        expect(page).to have_content agent.name

        click_button 'Agent Information'
        expect(page).to have_content('Connected')
        expect(page).to have_content(project.name)
      end
    end

    context 'when there are mapped and unmapped agents' do
      let_it_be(:agent_two) do
        create(:ee_cluster_agent, :with_existing_workspaces_agent_config, project: project, created_by_user: user)
      end

      let_it_be(:cluster_agent_mapping) do
        create(
          :namespace_cluster_agent_mapping,
          user: user, agent: agent,
          namespace: group
        )
      end

      it 'displays all agents in the All agents tab with availability status' do
        click_link 'All agents'

        expect(page).to have_content agent.name
        expect(page).to have_content agent_two.name

        expect(page).to have_content 'Allowed'
        expect(page).to have_content 'Blocked'
      end

      it 'allows mapping or unmapping agents' do
        first_agent_row_selector = 'tbody tr:first-child'

        click_link 'All agents'

        # Executes block action on the first agent
        within first_agent_row_selector do
          expect(page).to have_content('Allowed')

          click_button 'Block'
        end

        expect(page).to have_content('Block agent')

        click_button 'Block agent'

        wait_for_requests

        # Reverts the block action by allowing the agent
        within first_agent_row_selector do
          expect(page).to have_content('Blocked')

          click_button 'Allow'

          wait_for_requests
        end

        expect(page).to have_content('Allow agent')

        click_button 'Allow agent'

        expect(page).to have_content('Allowed')
      end
    end
  end
end
