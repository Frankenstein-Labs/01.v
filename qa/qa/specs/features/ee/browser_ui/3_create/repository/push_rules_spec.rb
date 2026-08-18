# frozen_string_literal: true

module QA
  RSpec.describe 'Create', feature_category: :source_code_management do
    describe 'Push rules', :requires_admin do
      let!(:creator) { Runtime::User::Store.test_user }
      let!(:project) { create(:project, :with_readme) }

      let(:file_name_limitation) { 'denied_file' }
      let(:file_size_limitation) { 1 }
      let(:branch_name_limitation) { project.default_branch }
      let(:needed_phrase_limitation) { 'allowed commit' }
      let(:deny_message_phrase_limitation) { 'denied commit' }

      before do
        Flow::Login.sign_in(as: creator)
        project.visit!

        Page::Project::Menu.perform(&:go_to_repository_settings)
        # TODO: implement push rules api support to remove rule setup via UI - https://docs.gitlab.com/ee/api/project_push_rules.html
        Page::Project::Settings::Repository.perform do |repository|
          repository.expand_push_rules do |push_rules|
            push_rules.fill_file_name(file_name_limitation)
            push_rules.fill_file_size(file_size_limitation)
            push_rules.fill_branch_name(branch_name_limitation)
            push_rules.fill_commit_message_rule(needed_phrase_limitation)
            push_rules.fill_deny_commit_message_rule(deny_message_phrase_limitation)
            push_rules.check_prevent_secrets
            push_rules.check_deny_delete_tag
            push_rules.click_submit
          end
        end
      end

      context 'when using non signed commits' do
        it 'allows an unrestricted push' do
          expect_no_error_on_push(file: standard_file)
        end

        it 'restricts files by name and size',
          quarantine: {
            only: { job: 'ee-qa-browser_ui-3_create' },
            type: :investigating,
            issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/455927'
          } do
          # Note: The file size limits in this test should be lower than the limits in
          # browser_ui/3_create/repository/push_over_http_file_size_spec to prevent
          # the limit set in that test from triggering in this test (which can happen
          # on Staging where the tests are run in parallel).
          # See: https://gitlab.com/gitlab-org/gitlab/-/issues/218620#note_361634705

          expected_error = 'You are attempting to check in one or more blobs which exceed the 1MiB limit'

          expect_error_on_push(
            file: {
              name: 'file',
              content: SecureRandom.hex(1000000)
            },
            error: expected_error)
          expect_error_on_push(
            file: {
              name: file_name_limitation,
              content: SecureRandom.hex(100)
            },
            error: Regexp.escape(
              %(File name #{file_name_limitation} was prohibited by the pattern "#{file_name_limitation}")
            )
          )
        end

        it 'restricts users by email format' do
          authors_email_limitation = "#{SecureRandom.hex(8)}@test.com"

          Page::Project::Settings::Repository.perform do |repository|
            repository.expand_push_rules do |push_rules|
              push_rules.fill_author_email(authors_email_limitation)
              push_rules.click_submit
            end
          end

          expect_error_on_push(
            file: standard_file,
            user: creator,
            error: Regexp.escape(
              "Committer's email '#{creator.email}' does not follow the pattern '#{authors_email_limitation}'"
            )
          )
        end

        it 'restricts branches by branch name' do
          expect_error_on_push(
            file: standard_file,
            branch: 'forbidden_branch',
            error: Regexp.escape(
              "Branch name 'forbidden_branch' does not follow the pattern '#{branch_name_limitation}'")
          )
        end

        it 'restricts commit by message format' do
          expect_no_error_on_push(file: standard_file, commit_message: needed_phrase_limitation)
          expect_error_on_push(
            file: standard_file,
            commit_message: 'forbidden message',
            error: Regexp.escape("Commit message does not follow the pattern '#{needed_phrase_limitation}'"))
          expect_error_on_push(
            file: standard_file,
            commit_message: "#{needed_phrase_limitation} - #{deny_message_phrase_limitation}",
            error: Regexp.escape("Commit message contains the forbidden pattern '#{deny_message_phrase_limitation}'"))
        end

        it 'restricts committing files with secrets' do
          expect_error_on_push(
            file: {
              name: 'id_rsa',
              content: SecureRandom.hex(100)
            },
            error: Regexp.escape('File name id_rsa was prohibited by the pattern "id_rsa$"'))
        end

        it 'restricts removal of tag' do
          tag = create(:tag, project: project, ref: project.default_branch, name: "test_tag")

          expect_error_on_push(file: standard_file, tag: tag.name, error: 'You cannot delete a tag')
        end

        it 'restricts non-member users' do
          non_member_user = build(:user,
            username: creator.username,
            password: creator.password,
            name: 'non_member_user',
            email: 'non_member_user@non_member_user.com',
            api_client: creator.api_client)

          Page::Project::Settings::Repository.perform do |repository|
            repository.expand_push_rules do |push_rules|
              push_rules.check_restrict_author
              push_rules.click_submit
            end
          end

          expect_error_on_push(
            file: standard_file,
            user: non_member_user,
            error: Regexp.escape("Author '#{non_member_user.email}' is not a member of team"))
        end

        it 'restricts unverified emails' do
          Page::Project::Settings::Repository.perform do |repository|
            repository.expand_push_rules do |push_rules|
              push_rules.check_committer_restriction
              push_rules.click_submit
            end
          end

          expect_no_error_on_push(file: standard_file)
          expect_error_on_push(
            file: standard_file,
            error: 'You can only push commits if the committer email is one of your own verified emails',
            user: build(:user, name: creator.name, username: creator.username, password: creator.password,
              email: 'unverified@example.com')
          )
        end
      end

      context 'when using signed commits' do
        let(:gpg) { Resource::UserGPG.fabricate_via_api! }

        before do
          Page::Project::Settings::Repository.perform do |repository|
            repository.expand_push_rules do |push_rules|
              push_rules.check_reject_unsigned_commits
              push_rules.click_submit
            end
          end
        end

        it 'restricts to signed commits' do
          expect_no_error_on_push(file: standard_file, gpg: gpg)
          expect_error_on_push(file: standard_file, error: 'Commit must be signed with a GPG key')
        end
      end

      def standard_file
        {
          name: 'file',
          content: SecureRandom.hex(100)
        }
      end

      def push(commit_message:, branch:, file:, user:, tag:, gpg:, max_attempts:)
        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = project
          push.commit_message = commit_message
          push.new_branch = branch != project.default_branch
          push.branch_name = branch
          push.user = user
          push.files = [file] if tag.nil?
          push.tag_name = tag unless tag.nil?
          push.gpg_key_id = gpg.key_id unless gpg.nil?
          push.max_attempts = max_attempts if max_attempts
        end
      end

      def expect_no_error_on_push(
        file:,
        commit_message: 'allowed commit',
        branch: project.default_branch,
        user: creator,
        tag: nil,
        gpg: nil
      )
        expect do
          push(
            commit_message: commit_message,
            branch: branch,
            file: file,
            user: user,
            tag: tag,
            gpg: gpg,
            max_attempts: 3)
        end.not_to raise_error
      end

      def expect_error_on_push(
        file:,
        commit_message: 'allowed commit',
        branch: project.default_branch,
        user: creator,
        tag: nil,
        gpg: nil,
        error: nil
      )
        expect do
          push(
            commit_message: commit_message,
            branch: branch,
            file: file,
            user: user,
            tag: tag,
            gpg: gpg,
            max_attempts: 1)
        end.to raise_error(QA::Support::Run::CommandError, /#{error}/)
      end
    end
  end
end
