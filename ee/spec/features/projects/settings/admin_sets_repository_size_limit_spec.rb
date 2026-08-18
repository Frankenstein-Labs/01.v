# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects settings > Admin sets repository size limit', :js, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project) }
  let_it_be(:admin) { create(:admin, owner_of: project) }

  before do
    stub_licensed_features(repository_size_limit: true)

    sign_in(admin)
  end

  it 'admin can set the repository size limit field when in admin mode', :enable_admin_mode do
    visit edit_project_path(project)

    fill_in 'Repository size limit (MiB)', with: '100'

    click_button 'Save changes', match: :first

    expect(page).to have_field 'Repository size limit (MiB)', with: '100'
  end

  it 'admin does not see the repository size limit field when not in admin mode' do
    visit edit_project_path(project)

    expect(page).to have_field 'Project ID', with: project.id
    expect(page).not_to have_field 'Repository size limit (MiB)'
  end
end
