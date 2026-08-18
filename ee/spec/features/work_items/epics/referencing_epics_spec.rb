# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Referencing Epics', :js, feature_category: :portfolio_management do
  let(:user) { create(:user) }
  let(:group) { create(:group, :public) }
  let(:epic) { create(:epic, group: group) }
  let(:project) { create(:project, :public) }

  let(:full_reference) { epic.to_reference(full: true) }

  before do
    stub_licensed_features(epics: true)
  end

  describe 'reference on an issue' do
    before do
      sign_in(user)
    end

    context 'when referencing epics from the direct parent' do
      let(:epic2) { create(:epic, group: group) }
      let(:short_reference) { epic2.to_reference }
      let(:text) { "Check #{full_reference} #{short_reference}" }
      let(:child_project) { create(:project, :public, group: group) }
      let(:issue) { create(:issue, project: child_project, description: text) }

      it 'displays link to the reference' do
        visit project_issue_path(child_project, issue)

        within_testid('work-item-description-wrapper') do
          expect(page).to have_link(epic.to_reference, href: group_epic_path(group, epic))
          expect(page).to have_link(short_reference, href: group_epic_path(group, epic2))
        end
      end
    end

    context 'when referencing an epic from another group' do
      let(:text) { "Check #{full_reference}" }
      let(:issue) { create(:issue, project: project, description: text) }

      context 'when non group member displays the issue' do
        context 'when referenced epic is in a public group' do
          it 'displays link to the reference' do
            visit project_issue_path(project, issue)

            within_testid('work-item-description-wrapper') do
              expect(page).to have_link(full_reference, href: group_epic_path(group, epic))
            end
          end
        end

        context 'when referenced epic is in a private group' do
          before do
            group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
          end

          it 'does not display link to the reference' do
            visit project_issue_path(project, issue)

            within_testid('work-item-description-wrapper') do
              expect(page).not_to have_link
            end
          end
        end
      end

      context 'when a group member displays the issue' do
        context 'when referenced epic is in a private group' do
          before do
            group.add_developer(user)
            group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
          end

          it 'displays link to the reference' do
            visit project_issue_path(project, issue)

            within_testid('work-item-description-wrapper') do
              expect(page).to have_link(full_reference, href: group_epic_path(group, epic))
            end
          end
        end
      end
    end
  end

  describe 'note cross-referencing' do
    let(:issue) { create(:issue, project: project) }

    before do
      group.add_developer(user)
      sign_in(user)
    end

    context 'when referencing an epic from an issue note' do
      let(:note_text) { "Check #{epic.to_reference(full: true)}" }

      before do
        visit project_issue_path(project, issue)

        fill_in 'Add a reply', with: note_text
        click_button 'Comment'
      end

      it 'creates a note with reference and cross references the epic', :sidekiq_might_not_need_inline do
        page.within('li.note') do
          expect(page).to have_text(note_text)
          expect(page).to have_link(epic.to_reference(full: true))
        end

        click_link(epic.to_reference(full: true))

        within_testid('system-note-content') do
          expect(page).to have_content('mentioned in issue')
          expect(page).to have_link(issue.to_reference(full: true))
        end
      end
    end

    context 'when referencing an issue from an epic' do
      let(:note_text) { "Check #{issue.to_reference(full: true)}" }

      before do
        visit group_epic_path(group, epic)

        fill_in 'Add a reply', with: note_text
        click_button 'Comment'
      end

      it 'creates a note with reference and cross references the issue', :sidekiq_might_not_need_inline do
        within_testid('note-wrapper') do
          expect(page).to have_content(note_text)
        end

        visit project_issue_path(project, issue)

        page.within('li.system-note') do
          expect(page).to have_content('mentioned in epic')
          expect(page).to have_link(epic.work_item.to_reference(full: true))
        end
      end
    end
  end
end
