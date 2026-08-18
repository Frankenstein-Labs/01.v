# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic in issue sidebar', :js, feature_category: :team_planning do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:epic1) { create(:epic, group: group, title: 'Epic Foo') }
  let_it_be(:epic2) { create(:epic, group: group, title: 'Epic Bar') }
  let_it_be(:epic3) { create(:epic, group: group, title: 'Epic Baz') }
  let_it_be(:work_item_epic) { create(:work_item, :epic, namespace: group, title: 'Work item Epic') }

  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:epic_issue) { create(:epic_issue, epic: epic1, issue: issue) }

  let_it_be(:subgroup) { create(:group, :public, parent: group) }
  let_it_be(:subproject) { create(:project, :public, group: subgroup) }
  let_it_be(:subepic) { create(:epic, group: subgroup, title: 'Subgroup epic') }
  let_it_be(:subissue) { create(:issue, project: subproject) }

  shared_examples 'epic in issue sidebar' do
    context 'projects within a group' do
      before do
        visit project_issue_path(project, issue)
      end

      it 'shows epics select dropdown and supports searching', :aggregate_failures do
        within_testid('work-item-parent') do
          expect(page).to have_link(epic1.title)

          click_button 'Edit'

          expect_listbox_items([work_item_epic.title, epic3.title, epic2.title, epic1.title])

          send_keys 'Bar'

          expect_no_listbox_item(work_item_epic.title)
          expect_no_listbox_item(epic3.title)
          expect_no_listbox_item(epic1.title)
          expect_listbox_items([epic2.title])

          select_listbox_item(epic2.title)

          expect(page).to have_link(epic2.title)
        end
      end
    end

    context 'project within a subgroup' do
      before do
        visit project_issue_path(subproject, issue)
      end

      it 'shows all epics belonging to the sub group and its parents', :aggregate_failures do
        within_testid('work-item-parent') do
          click_button 'Edit'

          expect_listbox_items([subepic.title, work_item_epic.title, epic3.title, epic2.title, epic1.title])
        end
      end
    end

    context 'personal projects' do
      # TODO update test to not expect testid once https://gitlab.com/gitlab-org/gitlab/-/issues/553969 is complete
      it 'does not show epic in issue sidebar' do
        personal_project = create(:project, :public)
        other_issue = create(:issue, project: personal_project)
        visit project_issue_path(personal_project, other_issue)

        expect(page).to have_testid('work-item-parent')
      end
    end
  end

  context 'when epics available' do
    before do
      stub_licensed_features(epics: true)
      group.add_owner(user)
      sign_in(user)
    end

    it_behaves_like 'epic in issue sidebar'

    context 'with namespaced plans', :saas do
      before do
        stub_application_setting(check_namespace_plan: true)
      end

      context 'group has license' do
        before do
          create(:gitlab_subscription, :ultimate, namespace: group)
        end

        it_behaves_like 'epic in issue sidebar'
      end

      context 'group has no license' do
        # TODO update test to not expect testid once https://gitlab.com/gitlab-org/gitlab/-/issues/553969 is complete
        it 'does not show epic for public projects and groups' do
          visit project_issue_path(project, issue)

          expect(page).to have_testid('work-item-parent')
        end
      end
    end
  end

  context 'when epics unavailable' do
    before do
      stub_licensed_features(epics: false)
      group.add_owner(user)
      sign_in(user)
    end

    it 'does not show epic in issue sidebar' do
      visit project_issue_path(project, issue)

      expect(page).not_to have_testid('work-item-parent')
    end
  end
end
