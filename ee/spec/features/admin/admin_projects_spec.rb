# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin Projects', feature_category: :permissions do
  context 'when user is a regular user with read_admin_projects custom admin role', :js do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:role) { create(:admin_member_role, :read_admin_projects, user: current_user) }

    let_it_be(:authorized_project) { create(:project, owners: [current_user]) }
    let_it_be(:unauthorized_project) { create(:project, :private) }

    before do
      stub_licensed_features(custom_roles: true)

      enable_admin_mode!(current_user)

      sign_in(current_user)
    end

    describe 'list' do
      it 'does not render admin-only action buttons' do
        visit admin_projects_path

        expect(page).not_to have_content("New Project")
        expect(page).to have_content(authorized_project.name)

        within_testid("projects-list-item-#{authorized_project.id}") do
          expect(has_testid?('projects-list-item-actions')).to be false
        end
      end

      it 'displays projects the user is not a member of' do
        visit admin_projects_path

        expect(page).to have_content(unauthorized_project.name)
      end
    end

    describe 'show', :aggregate_failures do
      let_it_be(:project) { create(:project) }

      before do
        stub_licensed_features(custom_roles: true)

        enable_admin_mode!(current_user)

        sign_in(current_user)
      end

      it 'shows the project without admin-only buttons' do
        visit admin_project_path(project)

        expect(page).to have_content project.name
        expect(page).not_to have_content("Edit")
      end
    end
  end

  context 'when current user is an admin', :js do
    let_it_be(:current_user) { create(:admin) }

    before do
      enable_admin_mode!(current_user)
      sign_in(current_user)
    end

    describe 'list' do
      let_it_be(:project) { create(:project) }

      it 'renders admin-only buttons' do
        visit admin_projects_path

        expect(page).to have_content("New Project")
      end

      it 'renders admin-only action buttons' do
        visit admin_projects_path

        expect(page).to have_content(project.name)

        find_by_testid('projects-list-item-actions').click

        within_testid('projects-list-item-actions') do
          expect(page).to have_content('Edit')
          expect(page).to have_content('Delete')
        end
      end
    end
  end
end
