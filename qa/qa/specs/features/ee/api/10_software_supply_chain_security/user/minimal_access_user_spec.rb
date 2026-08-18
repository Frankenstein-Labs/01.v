# frozen_string_literal: true

module QA
  RSpec.describe 'Software Supply Chain Security', feature_category: :system_access do
    describe 'User with minimal access to group', :requires_admin do
      include QA::Support::Helpers::Project

      let(:user_with_minimal_access) { create(:user, :with_personal_access_token) }
      let(:user_api_client) { user_with_minimal_access.api_client }
      let(:group) { create(:group, path: "group-for-minimal-access-#{SecureRandom.hex(8)}") }
      let!(:project) { create(:project, :with_readme, name: 'project-for-minimal-access', group: group) }

      before do
        wait_until_project_is_ready(project)

        group.sandbox.add_member(user_with_minimal_access, Resource::Members::AccessLevel::MINIMAL_ACCESS)
      end

      it 'is not allowed to push code via the CLI' do
        expect do
          Resource::Repository::Push.fabricate! do |push|
            push.repository_http_uri = project.repository_http_location.uri
            push.file_name = 'test.txt'
            push.file_content = "# This is a test project named #{project.name}"
            push.commit_message = 'Add test.txt'
            push.branch_name = 'new_branch'
            push.user = user_with_minimal_access
          end
        end.to raise_error(QA::Support::Run::CommandError, /You are not allowed to push code to this project/)
      end

      it 'is not allowed to create a file via the API' do
        expect do
          create(:file,
            api_client: user_api_client,
            project: project,
            branch: 'new_branch')
        end.to raise_error(Resource::ApiFabricator::ResourceFabricationFailedError, /403 Forbidden/)
      end

      it 'is not allowed to commit via the API', :smoke do
        expect do
          create(:commit,
            api_client: user_api_client,
            project: project,
            branch: 'new_branch',
            start_branch: project.default_branch,
            commit_message: 'Add new file',
            actions: [{ action: 'create', file_path: 'test.txt', content: 'new file' }])
        end.to raise_error(Resource::ApiFabricator::ResourceFabricationFailedError,
          /403 Forbidden - You are not allowed to push into this branch/)
      end
    end
  end
end
