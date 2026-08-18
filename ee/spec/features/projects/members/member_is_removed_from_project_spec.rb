# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Members > Member is removed from project', :js, feature_category: :groups_and_projects do
  include Spec::Support::Helpers::ModalHelpers
  include Features::MembersHelpers

  let_it_be(:project, freeze: false) { create(:project, :with_namespace_settings) }

  let_it_be_with_reload(:user) { create(:user, maintainer_of: project) }
  let_it_be_with_reload(:other_user) { create(:user, maintainer_of: project) }

  before do
    sign_in(user)

    visit project_project_members_path(project)
  end

  def leave_project
    show_actions_for_username(user)
    click_button _('Leave project')

    within_modal do
      click_button _('Leave')
    end

    expect(page).to have_current_path(dashboard_projects_path, ignore_query: true)
  end

  it 'user is removed from project' do
    leave_project

    expect(project.reload.users.exists?(user.id)).to be(false)
  end

  context 'when the user has been specifically allowed to access a protected branch' do
    let_it_be(:matching_protected_branch, freeze: false) { create(:protected_branch, authorize_user_to_push: user, authorize_user_to_merge: user, project: project) }
    let_it_be(:non_matching_protected_branch) { create(:protected_branch, authorize_user_to_push: other_user, authorize_user_to_merge: other_user, project: project) }

    it 'user leaves project' do
      leave_project

      expect(project.reload.users.exists?(user.id)).to be(false)
      expect(matching_protected_branch.push_access_levels.where(user: user)).not_to exist
      expect(matching_protected_branch.merge_access_levels.where(user: user)).not_to exist
      expect(non_matching_protected_branch.push_access_levels.where(user: other_user)).to exist
      expect(non_matching_protected_branch.merge_access_levels.where(user: other_user)).to exist
    end
  end
end
