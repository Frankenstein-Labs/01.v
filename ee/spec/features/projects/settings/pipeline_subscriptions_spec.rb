# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project Subscriptions', :js, feature_category: :continuous_integration do
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group_one) { create(:group) }
  let_it_be(:group_two) { create(:group) }
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:upstream_project) { create(:project, :public, :repository, namespace: group_one) }
  let_it_be(:downstream_project) do
    create(:project, :public, :repository, upstream_projects: [project], namespace: group_two)
  end

  before_all do
    project.add_maintainer(user)
    upstream_project.add_maintainer(user)
    downstream_project.add_maintainer(user)
  end

  before do
    stub_licensed_features(ci_project_subscriptions: true)

    sign_in(user)
    visit project_settings_ci_cd_path(project)
  end

  it 'renders the list of downstream projects', :aggregate_failures do
    within_testid('downstream-project-subscriptions') do
      expect(page).to have_testid('crud-count', text: '1', exact_text: true)
      expect(page).to have_content(downstream_project.name)
      expect(page).to have_content(downstream_project.owner.name)
    end
  end

  it 'doesn\'t allow to delete downstream projects', :aggregate_failures do
    within_testid('downstream-project-subscriptions') do
      expect(page).to have_content(downstream_project.name)
      expect(page).not_to have_button('Delete subscription')
    end
  end

  it 'successfully creates new pipeline subscription', :aggregate_failures do
    within_testid('upstream-project-subscriptions') do
      click_on 'Add new'

      fill_in 'Project path', with: upstream_project.full_path

      click_on 'Subscribe'

      expect(page).to have_testid('crud-count', text: '1', exact_text: true)
      expect(page).to have_content(upstream_project.name)
      expect(page).to have_content(upstream_project.namespace.name)
    end

    expect(page).to have_content('Subscription successfully created.')
  end

  it 'shows alert warning when unsuccessful in creating a pipeline subscription', :aggregate_failures do
    within_testid('upstream-project-subscriptions') do
      click_on 'Add new'

      fill_in 'Project path', with: 'wrong/path'

      click_on 'Subscribe'

      expect(page).to have_testid('crud-count', text: '0', exact_text: true)
      expect(page).to have_content('This project is not subscribed to any project pipelines.')
    end

    # rubocop:disable Layout/LineLength -- The error message is longer than the line limit
    expect(page).to have_content("The resource that you are attempting to access does not exist or you don't have permission to perform this action")
    # rubocop:enable Layout/LineLength
  end

  it 'removes a pipeline subscription' do
    within_testid('upstream-project-subscriptions') do
      click_on 'Add new'

      fill_in 'Project path', with: upstream_project.full_path

      click_on 'Subscribe'
    end

    expect(page).to have_content('Subscription successfully created.')

    click_on 'Delete subscription'

    within_modal do
      click_button 'OK'
    end

    expect(page).to have_content('Subscription successfully deleted.')
  end
end
