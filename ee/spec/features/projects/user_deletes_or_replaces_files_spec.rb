# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Files > User deletes or replaces files', :js, feature_category: :source_code_management do
  include DropzoneHelper

  let(:fork_message) do
    "You're not allowed to make changes to this project directly. " \
      "A fork of this project has been created that you can make changes in, so you can submit a merge request."
  end

  let(:commit_message) { 'New commit message' }

  # Create user first to ensure namespace is properly set up
  let_it_be(:user) do
    user = create(:user)
    # Explicitly create and verify namespace
    create(:namespace, owner: user, path: user.username)
    user.reload # Ensure user has the namespace loaded
    user
  end

  let_it_be(:user2) { create(:user) }

  let_it_be(:project) { create(:project, :repository, name: 'Another Project', path: 'another-project') }

  let_it_be(:project_tree_path_root_ref) { project_tree_path(project, project.repository.root_ref) }
  let_it_be(:project_non_default_branch_tree_path) do
    project_tree_path(project, 'non-default-branch')
  end

  def navigate_to_feature_1_file(path)
    visit(path)

    within_testid('file-tree-table') { click_link('encoding') }
    within_testid('file-tree-table') { click_link('feature-1.txt') }

    expect(page).to have_content('feature-1.txt')
  end

  before do
    create :path_lock, path: 'encoding/feature-1.txt', user: user2, project: project
    sign_in(user)
  end

  context 'when a user does not have write access' do
    before_all do
      project.add_reporter(user)
      project.repository.add_branch(user, 'non-default-branch', 'master')
    end

    context 'when a file is locked' do
      it 'does not allow to delete a file from a default branch' do
        navigate_to_feature_1_file(project_tree_path_root_ref)

        click_button 'File actions'

        expect(page).to have_button('Delete', disabled: true)
      end

      it 'does not allow to replace a file from a default branch' do
        navigate_to_feature_1_file(project_tree_path_root_ref)

        click_button 'File actions'

        expect(page).to have_button('Replace', disabled: true)
      end

      it 'deletes a file in a forked project from non-default branch', :js, :sidekiq_might_not_need_inline do
        # Create fork in advance to avoid issues
        Projects::ForkService.new(project, user, {}).execute
        navigate_to_feature_1_file(project_non_default_branch_tree_path)

        click_button 'File actions'
        click_on('Delete')

        fill_in(:commit_message, with: commit_message)
        click_button('Commit changes')

        fork = user.fork_of(project.reload)

        expect(page).to have_current_path(project_new_merge_request_path(fork), ignore_query: true)
        expect(page).to have_content(commit_message)
      end

      it 'replaces a file with a new one in a forked project from non-default branch',
        :sidekiq_might_not_need_inline do
        navigate_to_feature_1_file(project_non_default_branch_tree_path)

        click_button 'File actions'
        click_on('Replace')

        expect(page).to have_link('Fork')
        expect(page).to have_button('Cancel')

        click_link('Fork')

        expect(page).to have_content(fork_message)

        click_button 'File actions'
        click_on('Replace')
        find(".upload-dropzone-card").drop(Rails.root.join('spec/fixtures/doc_sample.txt'))

        page.within('#modal-replace-blob') do
          fill_in(:commit_message, with: 'Replacement file commit message')
          click_button('Commit changes')
        end

        expect(page).to have_content('Replacement file commit message')

        fork = user.fork_of(project.reload)

        expect(page).to have_current_path(project_new_merge_request_path(fork), ignore_query: true)

        click_link('Changes')

        expect(page).to have_content('Lorem ipsum dolor sit amet')
        expect(page).to have_content('Sed ut perspiciatis unde omnis')
      end
    end
  end
end
