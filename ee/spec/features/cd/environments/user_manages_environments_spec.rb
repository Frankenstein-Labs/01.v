# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User manages environments', :js, :with_current_organization,
  feature_category: :continuous_delivery do
  include ListboxHelpers

  let_it_be(:user) { create(:user, :organization_owner, organizations: [current_organization]) }

  before do
    sign_in(user)
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it 'renders a 404' do
      visit deploy_environments_organization_path(current_organization)

      expect(page).to have_content('Page not found')
    end
  end

  context 'when the ai_native_deploy feature flag is enabled' do
    it 'shows an empty state when there are no environments' do
      visit deploy_environments_organization_path(current_organization)

      expect(page).to have_content(s_('ContinuousDeployment|Get started with environments'))
      expect(page).to have_button(s_('ContinuousDeployment|Register your first environment'))
    end

    context 'with existing environments' do
      let_it_be(:staging_environment) do
        create(:cd_environment, :staging, organization: current_organization, name: 'staging-app')
      end

      let_it_be(:production_environment) do
        create(:cd_environment, :production, organization: current_organization, name: 'production-app')
      end

      it 'lists the environments' do
        visit deploy_environments_organization_path(current_organization)

        expect(page).to have_content(staging_environment.name)
        expect(page).to have_content(production_environment.name)
        expect(page).to have_testid('environment-card', count: 2)
      end

      it 'filters environments by tier' do
        visit deploy_environments_organization_path(current_organization)

        click_button 'Production'

        expect(page).to have_content(production_environment.name)
        expect(page).not_to have_content(staging_environment.name)
      end

      it 'searches environments by name' do
        visit deploy_environments_organization_path(current_organization)

        fill_in 'Filter environments', with: staging_environment.name

        expect(page).to have_content(staging_environment.name)
        expect(page).not_to have_content(production_environment.name)
      end
    end

    context 'when creating a new environment' do
      let_it_be(:project) { create(:project, organization: current_organization) }
      let_it_be(:agent) { create(:cluster_agent, project: project, name: 'my-agent') }

      it 'registers a new environment' do
        visit deploy_environments_organization_path(current_organization)

        expect(page).to have_content(s_('ContinuousDeployment|Get started with environments'))

        click_button 'Register environment'
        fill_in 'environment-name', with: 'production-eu'

        select_from_listbox(agent.name, from: s_('ContinuousDeployment|Select an agent'))

        within_testid('register-environment-panel-footer') do
          click_button 'Register environment'
        end

        expect(page).to have_content('production-eu')
      end
    end

    context 'when there are more environments than fit on one page' do
      before do
        allow(Resolvers::Cd::OrganizationEnvironmentsResolver).to receive(:max_page_size).and_return(3)
      end

      let_it_be(:environments) { create_list(:cd_environment, 4, organization: current_organization) }

      it 'loads the next page of environments' do
        visit deploy_environments_organization_path(current_organization)

        expect(page).to have_testid('environment-card', count: 3)

        click_button 'Load more'

        expect(page).to have_testid('environment-card', count: 4)
      end
    end
  end
end
