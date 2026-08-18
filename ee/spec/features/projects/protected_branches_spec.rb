# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Protected Branches', :js, feature_category: :source_code_management do
  include ProtectedBranchHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :repository, group: group, create_branch: 'protected') }

  context 'when a guest has custom role with `admin_protected_branch` assigned' do
    let_it_be(:guest) { create(:user) }

    let_it_be(:role) { create(:member_role, :guest, :admin_protected_branch, namespace: group) }
    let_it_be(:membership) do
      create(:group_member, :guest, member_role: role, user: guest, group: group)
    end

    let(:success_message) { s_('ProtectedBranch|Protected branch was successfully created') }

    before do
      stub_licensed_features(custom_roles: true)
      sign_in(guest)
    end

    it_behaves_like 'setting project protected branches'
  end

  context 'when a developer has custom role with `admin_protected_branch` assigned' do
    # Only Developer+ roles can access the project branches page
    let_it_be(:developer) { create(:user) }

    let_it_be(:role) { create(:member_role, :developer, :admin_protected_branch, namespace: group) }
    let_it_be(:membership) do
      create(:group_member, :developer, member_role: role, user: developer, group: group)
    end

    let_it_be_with_reload(:branch) { create(:protected_branch, project: project, name: 'protected') }

    before do
      stub_licensed_features(custom_roles: true)
      sign_in(developer)
    end

    it 'allows developer to remove protected branch' do
      visit project_branches_path(project)

      find('input[data-testid="branch-search"]').set('protected')
      find('input[data-testid="branch-search"]').native.send_keys(:enter)

      within('[data-name="protected"]') do
        within_testid('branch-more-actions') do
          find('.gl-new-dropdown-toggle').click
        end
      end

      expect(page).to have_button('Delete protected branch')
    end
  end
end
