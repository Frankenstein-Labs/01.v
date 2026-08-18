# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog', :js, :with_current_organization, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:foundational_agents_count) { Ai::FoundationalChatAgent.where(public: true).count }

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :in_group) }

  before do
    enable_ai_catalog
  end

  describe 'Agents' do
    before do
      sign_in(user)
      visit explore_ai_catalog_path
    end

    it('displays tabs') do
      page.within('.gl-tabs') do
        expect(page).to have_link('Agents')
        expect(page).to have_link('Flows')
      end
    end

    it('displays new agent button as link') do
      expect(page).to have_link('New agent')
    end

    context 'when ai_catalog_synthetic_foundational_items is disabled' do
      before do
        stub_feature_flags(ai_catalog_synthetic_foundational_items: false)
        visit explore_ai_catalog_path
      end

      it 'displays an empty list of agents' do
        expect(page).to have_content('Get started with the AI Catalog')
        expect(page).to have_content('Build agents and flows to automate tasks and solve complex problems.')

        agents = page.all('[data-testid="ai-catalog-item"]')
        expect(agents.length).to be(0)
      end
    end

    it 'displays the foundational agents' do
      agents = page.all('[data-testid="ai-catalog-item"]')
      expect(agents.length).to be(foundational_agents_count)
    end

    context 'when there are existing agents' do
      let_it_be(:agent1) { create(:ai_catalog_agent, :public, project_id: project.id, name: 'Agent 1') }
      let_it_be(:agent2) { create(:ai_catalog_agent, :public, project_id: project.id, name: 'Agent 2') }
      let_it_be(:agent3) { create(:ai_catalog_agent, :public, project_id: project.id, name: 'Agent 3') }
      let_it_be(:agent4) { create(:ai_catalog_agent, project_id: project.id, name: 'Agent 4') }
      let_it_be(:agent5) { create(:ai_catalog_agent, project_id: project.id, name: 'Agent 5') }
      let_it_be(:agent6) { create(:ai_catalog_agent, project_id: project.id, name: 'Agent 6') }

      it 'displays public agents' do
        agents = page.all('[data-testid="ai-catalog-item"]')
        expect(agents.length).to be(foundational_agents_count + 3)
      end

      context 'when user has permissions' do
        before_all do
          project.add_maintainer(user)
        end

        it 'displays public and private agents' do
          agents = page.all('[data-testid="ai-catalog-item"]')
          expect(agents.length).to be(foundational_agents_count + 6)
        end
      end
    end
  end

  describe 'legal disclaimer' do
    before do
      sign_in(user)
      visit explore_ai_catalog_agents_path
    end

    context 'when on Gitlab.com', :saas do
      it 'shows legal disclaimer on GitLab.com' do
        expect(page).to have_content('This catalog contains third-party content')
      end
    end

    context 'when not on Gitlab.com' do
      it 'does not show legal disclaimer' do
        expect(page).not_to have_content('This catalog contains third-party content')
      end
    end
  end
end
