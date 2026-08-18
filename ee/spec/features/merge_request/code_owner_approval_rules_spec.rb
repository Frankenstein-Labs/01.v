# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Code owner approval rules', :js, :sidekiq_inline, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:codeowner) { create(:user, :with_namespace) }

  let_it_be_with_reload(:project) do
    create(
      :project,
      :custom_repo,
      files: { 'CODEOWNERS' => "*.rb @#{codeowner.username}" },
      developers: user,
      maintainers: codeowner
    )
  end

  let_it_be_with_reload(:protected_branch) do
    create(
      :protected_branch,
      code_owner_approval_required: true,
      project: project,
      name: 'master'
    )
  end

  let_it_be(:add_readme) do
    project.repository.create_file(
      codeowner,
      'README.md',
      'A file',
      message: 'Add README',
      branch_name: 'master'
    )
  end

  let_it_be(:add_rb_file) do
    # Add a file on the target branch that will require code owner approval
    ruby_file = <<~CONTENT.strip_heredoc
      a = 1
      b = 2
      c = 3
    CONTENT
    project.repository.create_file(
      codeowner,
      'file.rb',
      ruby_file,
      message: 'add ruby file to target',
      branch_name: 'master'
    )
  end

  let(:source_branch) { generate(:branch) }

  let(:merge_request) do
    create(
      :merge_request,
      author: user,
      source_project: project,
      source_branch: source_branch,
      target_project: project,
      target_branch: 'master',
      merge_status: 'unchecked'
    )
  end

  before do
    stub_licensed_features(
      code_owner_approval_required: true,
      multiple_approval_rules: true
    )

    project.repository.add_branch(user, source_branch, add_readme)
  end

  shared_examples_for 'requires approval from Code Owners' do
    it 'shows approval is required from Code Owners' do
      sign_in(user)
      visit project_merge_request_path(project, merge_request)

      wait_for_all_requests

      page.within('.js-mr-approvals') do
        expect(page).to have_content('Requires 1 approval from Code Owners.')

        click_button 'Expand eligible approvers'

        expect(page).to have_content('*.rb')
      end
    end
  end

  context 'when not same file is on target branch' do
    before do
      # Add a file on the source branch that will require code owner approval
      ruby_file = <<~CONTENT.strip_heredoc
        a = 1
        b = 2
        c = 3
      CONTENT
      project.repository.create_file(
        user,
        'foo.rb',
        ruby_file,
        message: 'add foo.rb to source',
        branch_name: source_branch
      )

      check_mergeability_and_sync_code_owner_rules(merge_request)
    end

    it_behaves_like 'requires approval from Code Owners'
  end

  context 'when same file is on target branch' do
    context 'when content is the same' do
      before do
        # Add a file on the source branch that will require code owner approval
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
          branch_name: source_branch
        )

        check_mergeability_and_sync_code_owner_rules(merge_request)
      end

      it 'does not show approval is required from Code Owners' do
        sign_in(user)
        visit project_merge_request_path(project, merge_request)

        wait_for_all_requests

        page.within('.js-mr-approvals') do
          expect(page).to have_content('Approval is optional')

          click_button 'Expand eligible approvers'

          expect(page).not_to have_content('*.rb')
        end
      end
    end

    context 'when there are conflicts' do
      before do
        # Add a file on the source branch that will require code owner approval
        ruby_file = <<~CONTENT.strip_heredoc
          d = 1
          e = 2
          f = 3
        CONTENT
        project.repository.create_file(
          user,
          'file.rb',
          ruby_file,
          message: 'add ruby file to source',
          branch_name: source_branch
        )

        check_mergeability_and_sync_code_owner_rules(merge_request)
      end

      it_behaves_like 'requires approval from Code Owners'
    end
  end

  def check_mergeability_and_sync_code_owner_rules(merge_request)
    merge_request.check_mergeability
    ::MergeRequests::SyncCodeOwnerApprovalRules.new(merge_request).execute
  end
end
