# frozen_string_literal: true

module QA
  RSpec.describe 'Create', feature_category: :source_code_management do
    describe 'Project templates' do
      let!(:group) { create(:group) }

      let(:sandbox) { group.sandbox }
      let(:template_container_group_name) { "instance-template-container-group-#{SecureRandom.hex(8)}" }
      let(:template_container_group) do
        create(
          :group,
          path: template_container_group_name,
          description: 'Instance template container group',
          sandbox: sandbox
        )
      end

      let(:template_project) { create(:project, name: 'template-project-1', group: template_container_group) }

      let(:files) do
        [
          {
            name: 'file.txt',
            content: 'foo'
          },
          {
            name: 'README.md',
            content: 'bar'
          }
        ]
      end

      before do
        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = template_project
          push.files = files
          push.commit_message = 'Add test files'
        end
      end

      context 'when built-in', :requires_admin do
        before do
          Flow::Login.sign_in_as_admin
        end

        it 'successfully imports the project using template' do
          built_in = 'Ruby on Rails'

          group.visit!
          Page::Group::Show.perform(&:go_to_new_project)

          QA::Flow::Project.go_to_create_project_from_template

          Page::Project::New.perform do |new_page|
            expect(new_page).to have_text(built_in)
          end

          create_project_using_template(
            project_name: 'Project using built-in project template',
            namespace: group.name,
            template_name: built_in
          )

          Page::Project::Show.perform do |project|
            project.wait_for_import_success

            expect(project).to have_content("Initialized from '#{built_in}' project template")
            expect(project).to have_file(".ruby-version")
          end
        end
      end

      context 'when instance level', :requires_admin, :skip_live_env do
        before do
          Flow::Login.sign_in_as_admin

          Support::Retrier.retry_until(retry_on_exception: true) do
            Page::Main::Menu.perform(&:go_to_admin_area)
            Page::Admin::Menu.perform(&:go_to_template_settings)

            EE::Page::Admin::Settings::Templates.perform do |templates|
              templates.choose_custom_project_template(template_container_group_name)
            end

            Page::Admin::Menu.perform(&:go_to_template_settings)

            EE::Page::Admin::Settings::Templates.perform do |templates|
              Support::Waiter.wait_until(max_duration: 10) do
                templates.current_custom_project_template.include? template_container_group_name
              end
            end
          end

          group.visit!

          Page::Group::Show.perform(&:go_to_new_project)

          QA::Flow::Project.go_to_create_project_from_template
        end

        # Importing requires external_api_calls for setting application settings, this means this test
        # cannot currently run in the airgapped job
        # Failure issue: https://gitlab.com/gitlab-org/gitlab/-/issues/414247
        # Bug: https://gitlab.com/gitlab-org/gitlab/-/issues/421143
        # TODO: enable in airgapped job when bug is resolved
        it 'successfully imports the project using template', :external_api_calls do
          Page::Project::New.perform do |new_page|
            # Reload page in case template isn't available immediately
            new_page.retry_until(reload: true,
              message: "Expected #{template_project.name} to be present on page with a tab count of 1.") do
              new_page.go_to_create_from_template_instance_tab
              new_page.instance_template_tab_badge_text == "1" && new_page.has_text?(template_project.name)
            end
          end

          create_project_using_template(
            project_name: 'Project using instance level project template',
            namespace: group.full_path,
            template_name: template_project.name
          )

          Page::Project::Show.perform do |project|
            project.wait_for_import_success

            files.each do |file|
              expect(project).to have_file(file[:name])
            end
          end
        end
      end

      context 'when group level' do
        before do
          Flow::Login.sign_in

          Page::Main::Menu.perform(&:go_to_groups)
          Page::Dashboard::Groups.perform { |groups| groups.click_group(sandbox.name) }

          Page::Group::Menu.perform(&:go_to_general_settings)

          Page::Group::Settings::General.perform do |settings|
            settings.choose_custom_project_template(template_container_group_name)
          end

          Page::Group::Settings::General.perform do |settings|
            Support::Waiter.wait_until(max_duration: 10, reload_page: settings) do
              settings.current_custom_project_template.include? template_container_group_name
            end
          end

          group.visit!

          Page::Group::Show.perform(&:go_to_new_project)

          QA::Flow::Project.go_to_create_project_from_template

          Page::Project::New.perform(&:go_to_create_from_template_group_tab)
        end

        it 'successfully imports the project using template' do
          Page::Project::New.perform do |new_page|
            expect(new_page.group_template_tab_badge_text).to eq "1"
            expect(new_page).to have_text(template_container_group_name)
            expect(new_page).to have_text(template_project.name)
          end

          create_project_using_template(
            project_name: 'Project using group level project template',
            namespace: group.full_path,
            template_name: template_project.name
          )

          Page::Project::Show.perform do |project|
            project.wait_for_import_success

            files.each do |file|
              expect(project).to have_file(file[:name])
            end
          end
        end
      end

      def create_project_using_template(project_name:, namespace:, template_name:)
        Page::Project::New.perform do |new_page|
          new_page.use_template_for_project(template_name)
          new_page.choose_namespace(namespace)
          new_page.choose_name("#{project_name} #{SecureRandom.hex(8)}")
          new_page.add_description(project_name)
          new_page.set_visibility('Public')
          new_page.create_new_project
        end
      end
    end
  end
end
