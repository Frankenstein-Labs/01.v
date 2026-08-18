# frozen_string_literal: true

module QA
  RSpec.describe 'Systems', :orchestrated, :geo, feature_category: :geo_replication do
    describe 'project rename with Geo' do
      let(:geo_project_renamed) { "geo-after-rename-#{SecureRandom.hex(8)}" }

      it 'a project rename is reflected on a secondary Geo site' do
        original_project_name = 'geo-before-rename'
        original_readme_content = "The original project name was #{original_project_name}"
        readme_file_name = 'README.md'

        # create the project and push code
        QA::Flow::Login.while_signed_in(address: :geo_primary) do
          project = create(:project, name: original_project_name, description: 'Geo project to be renamed')

          geo_project_name = project.name

          Resource::Repository::ProjectPush.fabricate! do |push|
            push.project = project
            push.file_name = readme_file_name
            push.file_content = original_readme_content
            push.commit_message = "Add #{readme_file_name}"
          end

          # rename the project
          Flow::Login.sign_in

          Page::Dashboard::Projects.perform do |dashboard|
            dashboard.go_to_project(geo_project_name)
          end

          Page::Project::Menu.perform(&:go_to_general_settings)

          Page::Project::Settings::Main.perform do |settings|
            settings.rename_project_to(geo_project_renamed)
            expect(settings).to have_breadcrumb(geo_project_renamed)

            settings.expand_advanced_settings do |advanced_settings|
              advanced_settings.update_project_path_to(geo_project_renamed)
            end
          end
        end

        # check project appears renamed on secondary site
        QA::Runtime::Logger.debug('Visiting the secondary Geo site')

        QA::Flow::Login.while_signed_in(address: :geo_secondary) do
          Page::Main::Menu.perform(&:go_to_projects)

          Page::Dashboard::Projects.perform do |dashboard|
            dashboard.wait_for_project_replication(geo_project_renamed)

            dashboard.go_to_project(geo_project_renamed)
          end

          Page::Project::Show.perform do |show|
            show.wait_for_repository_replication

            expect(page).to have_content readme_file_name
            expect(page).to have_content original_readme_content
          end
        end
      end
    end
  end
end
