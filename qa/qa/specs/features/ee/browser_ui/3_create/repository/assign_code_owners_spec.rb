# frozen_string_literal: true

module QA
  RSpec.describe 'Create', feature_category: :source_code_management do
    describe 'Codeowners', :requires_admin do
      # Create one user to be the assigned approver and another user who will not be an approver
      let(:approver) { create(:user) }
      let(:non_approver) { create(:user) }
      let(:project) { create(:project, :with_readme, name: 'assign-approvers') }
      let(:branch_name) { 'protected-branch' }

      before do
        project.add_member(approver, Resource::Members::AccessLevel::DEVELOPER)
        project.add_member(non_approver, Resource::Members::AccessLevel::DEVELOPER)

        Flow::Login.sign_in

        project.visit!
      end

      it 'merge request assigns code owners as approvers' do
        # Commit CODEOWNERS to default branch
        create(:commit, project: project, commit_message: 'Add CODEOWNERS and test files', actions: [
          {
            action: 'create',
            file_path: 'CODEOWNERS',
            content: <<~CONTENT
              CODEOWNERS @#{approver.username}
            CONTENT
          }
        ])

        # Create a projected branch that requires approval from code owners
        Resource::ProtectedBranch.fabricate_via_browser_ui! do |protected_branch|
          protected_branch.branch_name = branch_name
          protected_branch.project = project
          protected_branch.require_code_owner_approval = true
        end

        # Push a new CODEOWNERS file
        Resource::Repository::Push.fabricate! do |push|
          push.repository_http_uri = project.repository_http_location.uri
          push.branch_name = branch_name + '-patch'
          push.file_name = 'CODEOWNERS'
          push.file_content = <<~CONTENT
            CODEOWNERS @#{non_approver.username}
          CONTENT
        end

        # Wait for GitLab to process the new branch
        project.wait_for_push_new_branch(branch_name + '-patch')

        # Create a merge request
        mr = Resource::MergeRequest.fabricate! do |merge_request|
          merge_request.project = project
          merge_request.target_new_branch = false
          merge_request.source_branch = branch_name + '-patch'
          merge_request.target_branch = branch_name
          merge_request.no_preparation = true
        end

        mr.visit!

        # Check that the merge request assigns the original code owner as an
        # approver (because the current CODEOWNERS file in the default branch
        # doesn't have the new owner yet)
        Page::MergeRequest::Show.perform do |show|
          show.edit!
          approvers = show.approvers

          expect(approvers.size).to eq(1)
          expect(approvers).to include(approver.name)
          expect(approvers).not_to include(non_approver.name)
        end
      end
    end
  end
end
