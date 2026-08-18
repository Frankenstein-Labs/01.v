# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Test cases', :js, feature_category: :quality_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:label1) { create(:label, project: project, title: 'bug') }
  let_it_be(:label2) { create(:label, project: project, title: 'enhancement') }
  let_it_be(:label3) { create(:label, project: project, title: 'documentation') }

  before do
    project.add_developer(user)
    stub_licensed_features(quality_management: true, requirements: true)

    sign_in(user)
  end

  context 'with test case creation form' do
    let(:title) { 'Sample title' }
    let(:description) { 'Sample _test case_ description.' }

    before do
      visit new_project_quality_test_case_path(project)

      wait_for_requests
    end

    it 'shows page title, title, description, confidentiality and label input fields' do
      page.within('.issuable-create-container') do
        expect(page.find('.page-title')).to have_content('New test case')
      end

      page.within('.issuable-create-container form') do
        expect(find_by_testid('issuable-title')).to have_selector('input#issuable-title')
        expect(find_by_testid('issuable-description')).to have_selector('.js-vue-markdown-field')
        expect(find_by_testid('issuable-confidential')).to have_selector('input#issuable-confidential')
        expect(find_by_testid('issuable-labels')).to have_selector('.labels-select-wrapper')
      end
    end

    it 'shows labels and footer actions within labels dropdown' do
      page.within('.issuable-create-container form .labels-select-wrapper') do
        page.find('.js-dropdown-button').click

        wait_for_requests

        expect(page.find('.js-labels-list .dropdown-content')).to have_selector('li', count: 3)
        expect(page.find('.js-labels-list .dropdown-footer')).to have_selector('li', count: 2)
      end
    end

    it 'shows page actions' do
      page.within('.issuable-create-container .footer-block') do
        expect(page.find('button')).to have_content('Submit test case')
        expect(page.find('a')).to have_content('Cancel')
      end
    end

    context 'when creating a confidential test case' do
      before do
        fill_and_submit_form(confidential: true)
      end

      it 'saves test case as confidential' do
        page.within('.content-wrapper .project-test-cases') do
          expect(page).to have_content(title)
          expect(page).to have_css('[data-testid="eye-slash-icon"]')
        end
      end
    end

    context 'when creating a non-confidential test case' do
      before do
        fill_and_submit_form(confidential: false)
      end

      it 'saves test case as non-confidential' do
        page.within('.content-wrapper .project-test-cases') do
          expect(page).to have_content(title)
          expect(page).not_to have_css('[data-testid="eye-slash-icon"]')
        end
      end
    end
  end
end

private

def fill_and_submit_form(confidential:)
  page.within('.issuable-create-container form') do
    fill_in _('Title'), with: title
    fill_in _('Description'), with: description

    find('#issuable-confidential').set(confidential)

    click_button _('Label')

    wait_for_requests

    click_link _('bug')
    click_link _('enhancement')
    click_link _('documentation')
  end

  click_button 'Submit test case'

  wait_for_requests
end
