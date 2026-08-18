# frozen_string_literal: true

module QA
  RSpec.describe 'Software Supply Chain Security', feature_category: :system_access do
    describe(
      'User with minimal access to group',
      :requires_admin
    ) do
      let(:admin_api_client) { Runtime::API::Client.as_admin }

      let(:user_with_minimal_access) { create(:user, api_client: admin_api_client) }

      let(:group) do
        group = create(:group, api_client: admin_api_client)
        group.sandbox.add_member(user_with_minimal_access, Resource::Members::AccessLevel::MINIMAL_ACCESS)
        group
      end

      let(:project) do
        create(:project,
          :with_readme,
          name: 'project-for-minimal-access',
          group: group,
          api_client: admin_api_client)
      end

      after do
        user_with_minimal_access&.remove_via_api!
        project&.remove_via_api!
        begin
          group&.remove_via_api!
        rescue Resource::ApiFabricator::ResourceNotDeletedError
          # It is ok if the group is already marked for deletion by another test
        end
      end

      it 'is not allowed to edit files via the UI' do
        Flow::Login.sign_in(as: user_with_minimal_access)
        project.visit!

        Page::Project::Show.perform do |project|
          project.click_file('README.md')
        end

        Page::File::Show.perform(&:click_edit)

        expect(page).to have_text("You're not allowed to make changes to this project directly.")
      end
    end
  end
end
