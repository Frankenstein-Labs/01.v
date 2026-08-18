# frozen_string_literal: true

module QA
  RSpec.describe 'Tenant Scale', feature_category: :organization do
    describe 'Group with members' do
      let(:source_group_with_members) { create(:group, path: "source-group-with-members_#{SecureRandom.hex(8)}") }
      let(:target_group_with_project) { create(:group, path: "target-group-with-project_#{SecureRandom.hex(8)}") }

      let!(:project) { create(:project, :with_readme, group: target_group_with_project) }

      let(:maintainer_user) { Runtime::User::Store.additional_test_user }

      before do
        source_group_with_members.add_member(maintainer_user, Resource::Members::AccessLevel::MAINTAINER)
      end

      it 'can be shared with another group with correct access level' do
        Flow::Login.sign_in

        target_group_with_project.visit!

        Page::Group::Menu.perform(&:go_to_members)
        Page::Group::Members.perform do |members|
          members.invite_group(source_group_with_members.path)

          expect(members).to have_group(source_group_with_members.path)
        end

        Page::Main::Menu.perform(&:sign_out)
        Flow::Login.sign_in(as: maintainer_user)

        Support::Waiter.wait_until(max_duration: 120, sleep_interval: 10,
          message: 'Wait until maintainer user created in project') do
          # use find_user instead of find_member because we need to wait for
          # project_authorizations table to be updated
          project.find_user(maintainer_user.username)
        end

        Page::Main::Menu.perform(&:go_to_projects)
        Page::Dashboard::Projects.perform do |projects|
          projects.click_member_tab
          expect(projects).to have_filtered_project_with_access_role(project.name, "Guest")
        end
      end
    end
  end
end
