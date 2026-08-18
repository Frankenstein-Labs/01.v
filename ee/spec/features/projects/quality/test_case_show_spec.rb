# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Test cases', :js, feature_category: :quality_management do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:label_bug) { create(:label, project: project, title: 'bug') }
  let_it_be(:label_doc) { create(:label, project: project, title: 'documentation') }
  let_it_be_with_reload(:test_case) do
    create(
      :quality_test_case,
      project: project,
      author: user,
      description: 'Sample description',
      created_at: 5.days.ago,
      updated_at: 2.days.ago,
      labels: [label_bug]
    )
  end

  before do
    project.add_developer(user)
    stub_licensed_features(quality_management: true)
    sign_in(user)
  end

  context 'with test case page' do
    before do
      visit project_quality_test_case_path(project, test_case)
      wait_for_requests
    end

    context 'for header' do
      it 'shows status, created date and author' do
        expect(page).to have_css('.gl-badge', text: 'Open')
        expect(page).to have_text('Test Case created 5 days ago')
        expect(page).to have_link(user.name)
      end

      it 'shows action buttons' do
        collapse_sidebar

        expect(page).to have_button('Archive')
        expect(page).to have_link('New test case', href: new_project_quality_test_case_path(project))
        expect(page).not_to have_button('Options')
      end

      it 'archives test case' do
        collapse_sidebar

        click_button('Archive')

        expect(page).to have_css('.gl-badge', text: 'Archived')
        expect(page).to have_button('Reopen')
      end
    end

    context 'for body' do
      it 'shows title, description and edit button' do
        collapse_sidebar

        expect(page).to have_text(test_case.title)
        expect(page).to have_text(test_case.description)
        expect(page).to have_button('Edit title and description')
      end

      it 'makes title and description editable on edit click' do
        collapse_sidebar

        click_button('Edit title and description')

        expect(page).to have_field('Title', with: test_case.title)
        expect(page).to have_field('Description', with: test_case.description)
        expect(page).to have_button('Save changes')
        expect(page).to have_button('Cancel')
      end

      it 'enters into zen mode when clicking on zen mode button' do
        collapse_sidebar

        click_button('Edit title and description')
        click_button('Go full screen')

        expect(page).to have_css('.zen-backdrop.fullscreen')
      end

      it 'update title and description' do
        title = 'Updated title'
        description = 'Updated test case description.'
        collapse_sidebar

        click_button('Edit title and description')
        fill_in('Title', with: title)
        fill_in('Description', with: description)
        click_button 'Save changes'

        expect(page).to have_text(title)
        expect(page).to have_text(description)
        expect(page).to have_text("Edited just now by #{user.name}")
      end
    end

    context 'for sidebar' do
      it 'shows expand/collapse button' do
        expect(page).to have_button('Collapse sidebar')
      end

      context 'for todo' do
        it 'adds test case as todo' do
          click_button('Add a to-do item')

          expect(page).to have_button('Mark as done')
        end

        it 'marks test case todo as done' do
          click_button('Add a to-do item')
          click_button('Mark as done')

          expect(page).to have_button('Add a to-do item')
        end
      end

      context 'for labels' do
        it 'shows assigned labels' do
          expect(page).to have_css('.labels-select-wrapper', text: label_bug.title)
        end

        context 'when editing' do
          before do
            within_testid('sidebar-labels') do
              click_button('Edit')
            end
          end

          it 'shows labels dropdown' do
            expect_listbox_item(label_bug.title)
            expect_listbox_item(label_doc.title)
            expect(page).to have_button('Create group label')
            expect(page).to have_link('Manage group labels')
          end

          it 'applies label using labels dropdown' do
            select_first_listbox_item(label_doc.title)
            send_keys(:escape)

            expect(page).to have_css('.labels-select-wrapper', text: label_doc.title)
          end
        end
      end

      describe 'confidentiality' do
        context 'when test case is not confidential' do
          it 'sets the test case to confidential' do
            within_testid('sidebar-confidentiality') do
              click_button('Edit')

              expect(page).to have_content(
                'You are going to turn on confidentiality. ' \
                'Only project members with at least the Planner role ' \
                'can view or be notified about this test case.'
              )

              click_button('Turn on')

              wait_for_requests

              expect(test_case.reload.confidential).to be(true)
              expect(page).to have_content(
                'Confidential'
              )
            end
          end
        end

        context 'when test case is confidential' do
          before do
            test_case.update!(confidential: true)
            refresh
            wait_for_requests
          end

          it 'sets the test case to not confidential' do
            within_testid('sidebar-confidentiality') do
              click_button('Edit')

              expect(page).to have_content(
                'You are going to turn off the confidentiality. ' \
                'This means everyone will be able to see this test case.' \
              )

              click_button('Turn off')

              wait_for_requests

              expect(test_case.reload.confidential).to be(false)
              expect(page).to have_content('Not confidential')
            end
          end
        end
      end
    end
  end

  describe 'for a nonexistent test case' do
    let(:test_case) { non_existing_record_id }

    it 'renders 404 page' do
      requests = inspect_requests do
        visit project_quality_test_case_path(project, test_case)
        wait_for_requests
      end

      expect(requests.first.status_code).to eq(404)
    end
  end

  private

  def collapse_sidebar
    within '.right-sidebar' do
      click_button "Collapse sidebar"
    end
  end
end
