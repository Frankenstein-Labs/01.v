# frozen_string_literal: true

module QA
  RSpec.describe 'Create', feature_category: :source_code_management do
    describe 'Restricted protected branch push and merge', :requires_admin do
      let(:user_developer) { create(:user, :with_personal_access_token) }
      let(:user_maintainer) { create(:user, :with_personal_access_token) }
      let(:branch_name) { 'protected-branch' }
      let(:commit_message) { 'Protected push commit message' }

      shared_examples 'user without push access' do |user|
        it 'fails to push' do
          expect { push_new_file(branch_name, as_user: send(user), max_attempts: 1) }.to raise_error(
            QA::Support::Run::CommandError,
            /You are not allowed to push code to protected branches on this project\.([\s\S]+)\[remote rejected\] #{branch_name} -> #{branch_name} \(pre-receive hook declined\)/)
        end
      end

      shared_examples 'selected developer' do
        it 'user pushes and merges' do
          push = push_new_file(branch_name, as_user: user_developer)

          expect(push.output).to match(/To create a merge request for protected-branch, visit/)

          merge_request = create(:merge_request,
            :no_preparation,
            project: project,
            target_new_branch: false,
            source_branch: branch_name)

          merged = merge_request.merge_via_api!

          expect(merged[:state]).to eq('merged')
        end
      end

      context 'when only one user is allowed to merge and push to a protected branch' do
        let(:project) { create(:project, :with_readme, name: 'user-with-access-to-protected-branch') }

        before do
          project.add_member(user_developer, Resource::Members::AccessLevel::DEVELOPER)
          project.add_member(user_maintainer, Resource::Members::AccessLevel::MAINTAINER)

          login

          Resource::ProtectedBranch.fabricate_via_browser_ui! do |protected_branch|
            protected_branch.branch_name = branch_name
            protected_branch.project = project
            protected_branch.allowed_to_merge = {
              users: [user_developer]
            }
            protected_branch.allowed_to_push = {
              users: [user_developer]
            }
          end
        end

        it_behaves_like 'user without push access', :user_maintainer
        it_behaves_like 'selected developer'
      end

      context 'when only one group is allowed to merge and push to a protected branch' do
        let(:group) { create(:group, path: "access-to-protected-branch-#{SecureRandom.hex(8)}") }

        let(:project) { create(:project, :with_readme, name: 'group-with-access-to-protected-branch') }

        before do
          login

          group.add_member(user_developer, Resource::Members::AccessLevel::DEVELOPER)
          project.invite_group(group, Resource::Members::AccessLevel::DEVELOPER)

          project.add_member(user_maintainer, Resource::Members::AccessLevel::MAINTAINER)

          Resource::ProtectedBranch.fabricate_via_browser_ui! do |protected_branch|
            protected_branch.branch_name = branch_name
            protected_branch.project = project
            protected_branch.allowed_to_merge = {
              groups: [group]
            }
            protected_branch.allowed_to_push = {
              groups: [group]
            }
          end
        end

        it_behaves_like 'user without push access', :user_maintainer
        it_behaves_like 'selected developer'
      end

      context 'when a sub-group has push access, a developer in the parent group does not have push access' do
        let(:parent_group) { create(:group, path: "access-to-protected-branch-#{SecureRandom.hex(8)}") }
        let(:sub_group) { create(:group, path: "sub-group-with-push-#{SecureRandom.hex(8)}", sandbox: parent_group) }
        let(:project) { create(:project, :with_readme, name: 'project-with-subgroup-with-push-access', group: parent_group) }

        before do
          login

          parent_group.add_member(user_developer, Resource::Members::AccessLevel::DEVELOPER)

          project.invite_group(sub_group, Resource::Members::AccessLevel::DEVELOPER)

          Resource::ProtectedBranch.fabricate_via_browser_ui! do |protected_branch|
            protected_branch.branch_name = branch_name
            protected_branch.project = project
            protected_branch.allowed_to_merge = {
              roles: Resource::ProtectedBranch::Roles::MAINTAINERS,
              groups: [sub_group]
            }
            protected_branch.allowed_to_push = {
              roles: Resource::ProtectedBranch::Roles::MAINTAINERS,
              groups: [sub_group]
            }
          end
        end

        it_behaves_like 'user without push access', :user_developer
      end

      def login(as_user: Runtime::User::Store.test_user)
        Page::Main::Menu.perform(&:sign_out_if_signed_in)

        Runtime::Browser.visit(:gitlab, Page::Main::Login)
        Page::Main::Login.perform do |login|
          login.sign_in_using_credentials(user: as_user)
        end
      end

      def push_new_file(branch_name, as_user: user, max_attempts: 3)
        Resource::Repository::Push.fabricate! do |push|
          push.repository_http_uri = project.repository_http_location.uri
          push.branch_name = branch_name
          push.new_branch = false
          push.user = as_user
          push.max_attempts = max_attempts
        end
      end
    end
  end
end
