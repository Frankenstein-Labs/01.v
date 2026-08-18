# frozen_string_literal: true

module QA
  RSpec.describe 'Create', feature_category: :source_code_management do
    describe(
      'File Locking',
      :requires_admin
    ) do
      let(:user_one) { create(:user, :with_personal_access_token) }
      let(:user_two) { create(:user, :with_personal_access_token) }
      let(:project) { create(:project, :with_readme, name: 'file_locking') }

      before do
        Flow::Login.sign_in

        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = project
          push.file_name = 'file'
          push.file_content = SecureRandom.hex(100)
          push.new_branch = false
        end

        add_to_project user: user_one
        add_to_project user: user_two

        Resource::ProtectedBranch.unprotect_via_api! do |branch|
          branch.project = project
          branch.branch_name = project.default_branch
        end
      end

      it 'locks a directory and tries to push as a second user' do
        push as_user: user_one, max_attempts: 3, branch: project.default_branch, file: 'directory/file'

        Flow::Login.sign_in(as: user_one, skip_page_validation: true)
        go_to_directory
        click_lock_directory

        expect_error_on_push for_file: 'directory/file', as_user: user_two
        expect_no_error_on_push for_file: 'directory/file', as_user: user_one
      end

      it 'locks a file and tries to push as a second user' do
        Flow::Login.sign_in(as: user_one, skip_page_validation: true)
        go_to_file
        click_lock_file

        expect_error_on_push as_user: user_two
        expect_no_error_on_push as_user: user_one
      end

      it 'merge request is blocked when a path is locked by another user' do
        push as_user: user_one, max_attempts: 3, branch: 'test'

        project.wait_for_push_new_branch('test')

        merge_request = create(:merge_request,
          :no_preparation,
          project: project,
          source_branch: 'test',
          target_branch: project.default_branch)

        Flow::Login.sign_in(as: user_one, skip_page_validation: true)
        go_to_file
        click_lock_file

        merge_request.wait_for_preparation

        merge_request.visit!

        Page::MergeRequest::Show.perform do |merge_request|
          expect(merge_request).to have_content('Merge blocked: 1 check failed', wait: 20)
          expect(merge_request).to have_content('All paths must be unlocked')
          expect(merge_request).to be_auto_mergeable
        end
      end

      it 'locks a file and unlocks in list' do
        Flow::Login.sign_in(as: user_one, skip_page_validation: true)
        go_to_file
        click_lock_file
        project.visit!

        Page::Project::Menu.perform(&:go_to_repository_locked_files)
        EE::Page::Project::PathLocks::Index.perform do |list|
          expect(list).to have_file_with_title 'file'
          list.unlock_file 'file'
        end

        expect_no_error_on_push as_user: user_two
      end

      def go_to_file
        project.visit!
        Page::Project::Show.perform do |project_page|
          project_page.click_file 'file'
        end
      end

      def go_to_directory
        project.visit!
        Page::Project::Show.perform do |project_page|
          project_page.click_file 'directory'
        end
      end

      def click_lock_directory
        Page::File::Show.perform(&:lock)
      end

      def click_lock_file
        # We use find here because these are gitlab-ui elements
        find('[data-testid="blob-overflow-menu"] > button').click
        # Click within dropdown
        click_button('Lock')
        # Click within confirmation dialog
        click_button('Lock')
      end

      def add_to_project(user:)
        create(:project_member, :developer, user: user, project: project)
      end

      def push(as_user:, max_attempts:, branch: project.default_branch, file: 'file')
        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = project
          push.new_branch = false unless branch != project.default_branch
          push.file_name = file
          push.file_content = SecureRandom.hex(100)
          push.user = as_user
          push.branch_name = branch
          push.max_attempts = max_attempts if max_attempts
        end
      end

      def expect_error_on_push(as_user:, for_file: 'file')
        expect do
          push as_user: as_user, max_attempts: 1, branch: project.default_branch, file: for_file
        end.to raise_error(
          QA::Support::Run::CommandError)
      end

      def expect_no_error_on_push(as_user:, for_file: 'file')
        expect do
          push as_user: as_user, max_attempts: 3, branch: project.default_branch, file: for_file
        end.not_to raise_error
      end
    end
  end
end
