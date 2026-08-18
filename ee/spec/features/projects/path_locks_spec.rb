# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Path Locks', :js, feature_category: :source_code_management do
  include Spec::Support::Helpers::ModalHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:project) { create(:project, :repository, namespace: user.namespace) }
  let(:tree_path) { project_tree_path(project, project.repository.root_ref) }

  before do
    project.add_maintainer(user)
    project.add_developer(other_user)
    sign_in(user)

    visit tree_path

    wait_for_requests
  end

  it 'locking and unlocking folders' do
    within '.tree-content-holder' do
      click_link "encoding"
    end

    wait_for_requests

    click_button 'Lock'

    within_modal do
      click_button 'Lock'
    end

    click_button 'Locked'

    expect(page).to have_content("Locked by #{user.name}")

    click_button 'Unlock directory'

    within_modal do
      click_button 'Unlock'
    end

    expect(page).to have_button('Lock')
  end

  it 'locking files' do
    page_tree = find('.tree-content-holder')

    within page_tree do
      click_link "VERSION"
    end

    within_testid('blob-controls') do
      click_button 'Lock'
    end

    within_modal do
      click_button 'Lock'
    end

    within_testid('blob-controls') do
      expect(page).to have_button('Locked')
    end

    sign_in other_user
    visit project_blob_path(project, File.join('master', 'VERSION'))

    within_testid('blob-controls') do
      click_button 'Locked'
    end

    expect(page).to have_content('You do not have permission to unlock this file.')
    expect(page).to have_no_button('Unlock file')
  end

  it 'unlocking files' do
    within find('.tree-content-holder') do
      click_link "VERSION"
    end

    within_testid('blob-controls') do
      click_button 'Lock'
    end

    within_modal do
      click_button 'Lock'
    end

    within_testid('blob-controls') do
      click_button 'Locked'
    end

    expect(page).to have_content("Locked by #{user.name}")
    expect(page).to have_link(user.name)

    click_button 'Unlock file'

    within_modal do
      click_button 'Unlock'
    end

    within_testid('blob-controls') do
      expect(page).to have_button('Lock')
    end
  end

  context 'when repository_lock_information feature flag is disabled' do
    before do
      stub_feature_flags(repository_lock_information: false)

      visit tree_path

      wait_for_requests
    end

    it 'locks files from the file actions dropdown' do
      within find('.tree-content-holder') do
        click_link "VERSION"
      end

      within_testid('blob-controls') do
        click_button 'File actions'
        click_button 'Lock'
      end

      within_modal do
        click_button 'Lock'
      end

      visit tree_path
      expect(page).to have_css("[aria-label='Locked by #{user.username}']")

      sign_in other_user
      visit project_blob_path(project, File.join('master', 'VERSION'))
      click_button 'File actions'
      expect(page).to have_button('Unlock', disabled: true)
    end

    it 'unlocks files from the file actions dropdown' do
      create(:path_lock, path: 'VERSION', user: user, project: project)

      visit project_blob_path(project, File.join('master', 'VERSION'))

      within_testid('blob-controls') do
        click_button 'File actions'
        click_button 'Unlock'
      end

      within_modal do
        click_button 'Unlock'
      end

      visit tree_path
      expect(page).to have_no_css("[aria-label='Locked by #{user.username}']")
    end

    it 'locking folders with the legacy lock button' do
      within '.tree-content-holder' do
        click_link "encoding"
      end

      click_button 'Lock'

      within_modal do
        click_button 'Ok'
      end

      expect(page).to have_button('Unlock')
    end
  end

  it 'managing of lock list' do
    create :path_lock, path: 'encoding', user: user, project: project

    click_link "Locked files"

    within '.js-path-locks' do
      expect(page).to have_content('encoding')
    end

    click_link "Unlock"

    accept_gl_confirm('Are you sure you want to unlock encoding?')

    expect(page).not_to have_content('encoding')
  end
end
