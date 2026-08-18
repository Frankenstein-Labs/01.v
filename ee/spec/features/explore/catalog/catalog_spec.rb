# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'CI/CD Catalog', :js, feature_category: :pipeline_composition do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:public_projects_with_components) do
    create_list(
      :project,
      3,
      :catalog_resource_with_components,
      :public,
      description: 'A simple component',
      namespace: namespace
    )
  end

  before_all do
    public_projects_with_components.map do |current_project|
      create(:ci_catalog_resource, :published, project: current_project)
    end
  end

  describe 'legal disclaimer' do
    before do
      visit explore_catalog_index_path
    end

    context 'when on Gitlab.com', :saas do
      it 'shows legal disclaimer on GitLab.com' do
        expect(page).to have_content('This catalog contains third-party content')
        expect(page).to have_content(
          'Use of this content is subject to the relevant content provider\'s terms of use.'
        )
        expect(page).to have_content('GitLab does not control and has no liability for third-party content')
      end
    end

    context 'when not on Gitlab.com' do
      it 'does not show legal disclaimer' do
        expect(page).not_to have_content('This catalog contains third-party content')
        expect(page).not_to have_content(
          'Use of this content is subject to the relevant content provider\'s terms of use.'
        )
        expect(page).not_to have_content('GitLab does not control and has no liability for third-party content')
      end
    end
  end
end
