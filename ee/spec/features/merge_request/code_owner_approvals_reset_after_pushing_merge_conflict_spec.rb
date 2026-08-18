# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Code owner approvals reset after pushing merge conflict to source branch", :js, :sidekiq_inline, feature_category: :code_review_workflow do
  include RepoHelpers
  let_it_be(:rb_approving_user) { create(:user, :with_namespace) }
  let_it_be(:user) { create(:user, :with_namespace) }

  context 'when the project has selective code owner removals' do
    let_it_be_with_reload(:project) do
      create(
        :project,
        :custom_repo,
        files: { 'CODEOWNERS' => "*.rb @#{rb_approving_user.username}" },
        reset_approvals_on_push: false,
        project_setting_attributes: { selective_code_owner_removals: true }
      )
    end

    let_it_be_with_reload(:protected_branch) do
      create(:protected_branch, code_owner_approval_required: true, project: project, name: 'master')
    end

    let_it_be(:add_readme) do
      project.repository.create_file(
        user,
        'README.md',
        'A file',
        message: 'Add README',
        branch_name: 'master'
      )
    end

    let_it_be(:add_rb_file_to_target_branch) do
      # Add a file on the target branch that will require code owner approval
      ruby_file = <<~CONTENT.strip_heredoc
        a = 1
        b = 2
        c = 3
      CONTENT
      project.repository.create_file(
        user,
        'file.rb',
        ruby_file,
        message: 'add ruby file to source',
        branch_name: 'master'
      )
    end

    let(:branch_name) { generate(:branch) }

    let!(:merge_request) do
      # Create a merge request adding a change that does not require codeowner approval
      project.repository.add_branch(user, branch_name, add_readme)
      project.repository.create_file(
        user,
        'textfile.txt',
        'A file',
        message: 'This does not require approval',
        branch_name: branch_name
      )

      create(:merge_request,
        author: user,
        source_project: project,
        source_branch: branch_name,
        target_project: project,
        target_branch: 'master',
        merge_status: 'unchecked'
      )
    end

    let(:add_conflict_with_rb_file_to_source_branch) do
      # Add a change to the target branch that should cause the merge request to require code owner approval
      ruby_file = <<~CONTENT.strip_heredoc
        a = 1
        c = 4
      CONTENT

      project.repository.create_file(
        user,
        'file.rb',
        ruby_file,
        message: 'add ruby file on branch',
        branch_name: branch_name
      )
    end

    before_all do
      project.add_developer(rb_approving_user)
      project.add_developer(user)
    end

    # We're ignoring server errors here because we're getting flaky failures
    # about `Gitlab::ExclusiveLease::LeaseWithinTransactionError` being raised
    # when `MergeRequests::MergeabilityCheckService` gets executed.
    #
    # We don't execute that service within a transaction and this error was not reproducible locally.
    context 'when the first merge request has been approved', :capybara_ignore_server_errors do
      before do
        stub_licensed_features(code_owner_approval_required: true, multiple_approval_rules: true)
        ::MergeRequests::SyncCodeOwnerApprovalRules.new(merge_request).execute

        create(
          :approval,
          merge_request: merge_request,
          user: rb_approving_user
        )
        sign_in(user)

        visit project_merge_request_path(project, merge_request)
        wait_for_all_requests
      end

      it 'is ready to merge' do
        page.within('.mr-widget-section') do
          expect(page).to have_content('Ready to merge')
        end
      end

      context 'and then push results in a merge conflict on a file that requires review from code owners' do
        before do
          simulate_post_receive(project, branch_name, create(:key, user: user).shell_id) do
            add_conflict_with_rb_file_to_source_branch
          end
        end

        it 'resets code owner approvals',
          quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/9466' do
          expect(merge_request.reload.approvals).to be_empty
          page.within('.mr-widget-section') do
            expect(page).not_to have_content('Ready to merge')
            expect(page).to have_content('Merge blocked')
          end

          page.within('.js-mr-approvals') do
            expect(page).to have_content('Requires 1 approval from Code Owners.')
          end
        end
      end
    end
  end
end
