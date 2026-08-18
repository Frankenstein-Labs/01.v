# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin Groups', feature_category: :groups_and_projects do
  context 'when current user is an admin', feature_category: :hosted_runners do
    include ::Ci::MinutesHelpers

    # `freeze: false` is required in this spec: one or more `let_it_be` subjects
    # cannot be frozen by default (deep_freeze traversal failure, a non-AR
    # subject, or an in-memory mutation that survives reload/refind). Do not
    # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
    # (see gitlab-org/gitlab#602925).
    let_it_be(:group, freeze: false) { create :group }
    let_it_be(:admin) { create(:admin) }
    let_it_be_with_reload(:project) { create(:project, namespace: group) }

    before do
      sign_in(admin)
      enable_admin_mode!(admin)
    end

    describe 'show a group' do
      context 'with compute usage' do
        before do
          project.update!(shared_runners_enabled: true)
          set_ci_minutes_used(group, 300)
          group.update!(shared_runners_minutes_limit: 400)
        end

        context 'when gitlab saas', :saas do
          it 'renders compute usage report' do
            visit admin_group_path(group)

            expect(page).to have_content('Compute quota: 300 / 400')
          end

          it 'renders additional compute minutes' do
            group.update!(extra_shared_runners_minutes_limit: 100)

            visit admin_group_path(group)

            expect(page).to have_content('Additional compute minutes:')
          end
        end

        context 'when self-managed' do
          it 'renders compute usage report' do
            visit admin_group_path(group)

            expect(page).not_to have_content('Compute quota: 300 / 400')
          end

          it 'does not render additional compute minutes' do
            group.update!(extra_shared_runners_minutes_limit: 100)

            visit admin_group_path(group)

            expect(page).not_to have_content('Additional compute minutes:')
          end
        end
      end
    end
  end

  context 'when current user is a regular user with read_admin_groups permission', :js do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:role) { create(:admin_member_role, :read_admin_groups, user: current_user) }

    before do
      stub_licensed_features(custom_roles: true)

      enable_admin_mode!(current_user)

      sign_in(current_user)
    end

    describe 'list' do
      let_it_be(:group, freeze: false) { create(:group, :private, owners: [current_user]) }
      let_it_be(:unauthorized_group) { create(:group, :private) }

      it 'does not render admin-only buttons' do
        visit admin_groups_path

        expect(page).not_to have_content("New group")
      end

      shared_examples 'does not render admin-only action buttons' do
        specify do
          visit admin_groups_path

          expect(page).to have_content(group.name)

          within_testid("groups-list-item-#{group.id}") do
            expect(has_testid?('groups-list-item-actions')).to be false
          end
        end
      end

      it_behaves_like 'does not render admin-only action buttons'

      it 'displays groups the user is not a member of' do
        visit admin_groups_path

        expect(page).to have_content(unauthorized_group.name)
      end
    end

    describe 'show', :aggregate_failures do
      let_it_be(:group, freeze: false) { create :group }

      it 'shows the group without admin-only buttons' do
        visit admin_group_path(group)

        expect(page).to have_content group.name
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
      let_it_be(:group, freeze: false) { create(:group) }

      it 'renders admin-only buttons' do
        visit admin_groups_path

        expect(page).to have_content("New group")
      end

      it 'renders admin-only action buttons' do
        visit admin_groups_path

        expect(page).to have_content(group.name)

        find_by_testid('groups-list-item-actions').click

        within_testid('groups-list-item-actions') do
          expect(page).to have_content('Edit')
          expect(page).to have_content('Delete')
        end
      end
    end
  end
end
