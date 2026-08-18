# frozen_string_literal: true

require "spec_helper"

RSpec.describe 'AI Catalog Enabling an agent', :js, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include ListboxHelpers
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:project) { create(:project, :with_duo_features_enabled, :in_group) }
  let_it_be(:project2) { create(:project, :with_duo_features_enabled, :in_group) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: [project, project2]) }

  let_it_be(:public_agent) do
    create(:ai_catalog_agent, :public, :with_released_version, project: project,
      name: 'Test agent', description: 'Test agent description')
  end

  let_it_be(:private_agent) do
    create(:ai_catalog_agent, :with_released_version, project: project,
      name: 'Test private agent', description: 'Test private agent description')
  end

  let(:agent) { public_agent }

  before do
    enable_ai_catalog
    sign_in(user)
  end

  describe 'from Explore > show page - when ai_catalog_bulk_item_consumer_create feature flag is on' do
    before do
      stub_feature_flags(ai_catalog_bulk_item_consumer_create: true)
      visit explore_ai_catalog_agent_path(agent)
    end

    context 'when user is a maintainer' do
      let(:user) { maintainer }

      context 'when agent is public' do
        it 'enables directly in multiple projects' do
          click_button 'Enable'

          within_modal do
            page.check(project.name_with_namespace)
            page.check(project2.name_with_namespace)
            click_button 'Enable'
          end

          expect(page).to have_content("Enabled in selected project(s).")
        end
      end
    end
  end

  describe 'from Explore > show page' do
    before do
      stub_feature_flags(ai_catalog_bulk_item_consumer_create: false)
      visit explore_ai_catalog_agent_path(agent)
    end

    context 'when user is a maintainer' do
      let(:user) { maintainer }

      context 'when agent is public' do
        it 'enables directly in project' do
          click_button 'Enable'

          within_modal do
            select_from_listbox(project.name_with_namespace, from: 'Select a project')
            click_button 'Enable'
          end

          expect(page).to have_content("Agent enabled in #{project.name}.")
        end
      end

      context 'when agent is private' do
        let(:agent) { private_agent }

        it 'enables directly in project' do
          click_button 'Enable'

          within_modal do
            expect(page).to have_content(project.name_with_namespace)
            click_button 'Enable'
          end
          wait_for_requests

          expect(page).to have_content("Agent enabled in #{project.name}.")
        end
      end
    end

    context 'when user is a developer' do
      let(:user) { developer }

      it 'shows modal but disables Enable button' do
        click_button 'Enable'
        wait_for_requests # wait for projects in dropdown to load

        within_modal do
          expect(page).to have_content('You must have the Maintainer or Owner role to enable an agent in a project.')
          expect(page).to have_button('Enable', disabled: true)
        end
      end
    end
  end

  describe 'from Project > show page' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :duo_workflow, project).and_return(true)
      # Mock the usage quota service to avoid external HTTP requests
      allow_next_instance_of(::Ai::UsageQuotaService) do |service|
        allow(service).to receive(:execute).and_return(ServiceResponse.success)
      end

      visit project_automate_agent_path(project, agent)
    end

    context 'when user is a maintainer' do
      let(:user) { maintainer }

      it 'enables agent directly in project' do
        click_button 'Enable'

        within_modal do
          click_button 'Enable'
        end
        wait_for_requests

        expect(page).to have_content("Agent enabled in #{project.name}.")
      end
    end

    context 'when user is a developer' do
      let(:user) { developer }

      it 'does not show Enabled button' do
        expect(page).to have_content(agent.name)
        expect(page).to have_button('Enable', disabled: true)
      end
    end
  end
end
