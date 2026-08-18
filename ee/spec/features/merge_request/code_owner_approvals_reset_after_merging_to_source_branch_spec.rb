# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Code owner approvals reset after merging to source branch", :js, :sidekiq_inline, feature_category: :code_review_workflow do
  include RepoHelpers
  let_it_be(:rb_approving_user) { create(:user) }
  let_it_be(:user) { create(:user) }

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

    let(:merge_request) do
      branch_name = generate(:branch)
      project.repository.create_file(
        user,
        'file.rb',
        'A file',
        message: 'Add file',
        branch_name: branch_name
      )

      create(:merge_request,
        author: user,
        source_project: project,
        source_branch: branch_name,
        target_project: project,
        target_branch: 'master',
        merge_status: 'can_be_merged'
      )
    end

    let(:codeowner_change_merge_request) do
      branch_name = generate(:branch)
      project.repository.create_file(
        user,
        'second_file.rb',
        'Another file',
        message: 'Add another file',
        branch_name: branch_name
      )

      create(:merge_request,
        author: user,
        source_project: project,
        source_branch: branch_name,
        target_project: project,
        target_branch: merge_request.source_branch
      )
    end

    let(:textfile_change_merge_request) do
      branch_name = generate(:branch)
      project.repository.create_file(
        user,
        'text.txt',
        'A text file',
        message: 'Add another file',
        branch_name: branch_name
      )

      create(:merge_request,
        author: user,
        source_project: project,
        source_branch: branch_name,
        target_project: project,
        target_branch: merge_request.source_branch
      )
    end

    before_all do
      project.add_developer(rb_approving_user)
      project.add_developer(user)
      create(:protected_branch, project: project, name: 'master', code_owner_approval_required: true)
    end

    context 'when the first merge request has been approved' do
      before do
        stub_licensed_features(code_owner_approval_required: true, multiple_approval_rules: true)

        ::MergeRequests::SyncCodeOwnerApprovalRules.new(merge_request).execute
        ::MergeRequests::ApprovalService.new(
          project: merge_request.project,
          current_user: rb_approving_user
        ).execute(merge_request)

        sign_in(user)
      end

      it 'is ready to merge' do
        visit project_merge_request_path(project, merge_request)

        wait_for_all_requests
        page.within('.mr-widget-section') do
          expect(page).to have_content('Ready to merge')
        end
      end

      context 'and the other merge request is merged' do
        before do
          visit project_merge_request_path(project, other_merge_request)
          source_branch = merge_request.source_branch
          simulate_post_receive(project, source_branch, create(:key, user: user).shell_id) do
            page.within('.mr-widget-section') do
              click_button('Merge')
            end
          end
        end

        context 'and the other merge request contains changes related to code owners' do
          let(:other_merge_request) { codeowner_change_merge_request }

          it 'resets code owner approvals for the first merge request',
            quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/438170' do
            visit project_merge_request_path(project, merge_request)
            page.within('.js-mr-approvals') do
              expect(page).to have_content('Requires 1 approval from Code Owners.')
            end
          end
        end

        context 'and the other merge request is not related to code owners' do
          let(:other_merge_request) { textfile_change_merge_request }

          it 'is ready to merge', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/446246' do
            visit project_merge_request_path(project, merge_request)

            wait_for_all_requests
            page.within('.mr-widget-section') do
              expect(page).to have_content('Ready to merge')
            end
          end
        end
      end
    end
  end
end
