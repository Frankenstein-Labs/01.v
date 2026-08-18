# frozen_string_literal: true

module QA
  RSpec.describe 'Systems', :orchestrated, :geo, feature_category: :geo_replication do
    describe 'GitLab SSH push' do
      let(:file_name) { 'README.md' }

      key = nil

      after do
        key&.remove_via_api!
      end

      context 'when regular git commit' do
        it "new Git data is viewable in UI on secondary Geo sites" do
          key_title = "Geo SSH #{Time.now.to_f}"
          file_content = 'This is a Geo project! Commit from primary.'
          project = nil

          QA::Flow::Login.while_signed_in(address: :geo_primary) do
            # Create a new SSH key for the user
            key = create(:ssh_key, title: key_title, expires_at: Date.today + 2)

            # Create a new Project
            project = create(:project, name: 'geo-project', description: 'Geo test project for SSH push')

            # Perform a git push over SSH directly to the primary
            Resource::Repository::ProjectPush.fabricate! do |push|
              push.ssh_key = key
              push.project = project
              push.file_name = file_name
              push.file_content = "# #{file_content}"
              push.commit_message = 'Add README.md'
            end.project.visit!

            # Validate git push worked and file exists with content
            Page::Project::Show.perform do |show|
              show.wait_for_repository_replication

              expect(page).to have_content(file_name)
              expect(page).to have_content(file_content)
            end
          end

          QA::Runtime::Logger.debug('*****Visiting the secondary Geo site*****')

          QA::Flow::Login.while_signed_in(address: :geo_secondary) do
            # Ensure project is displayed
            Page::Main::Menu.perform(&:go_to_projects)
            Page::Dashboard::Projects.perform do |dashboard|
              dashboard.wait_for_project_replication(project.name)
              dashboard.go_to_project(project.name)
            end

            # Validate the content looks the same as on the primary site
            Page::Project::Show.perform do |show|
              show.wait_for_repository_replication_with(file_content)

              expect(page).to have_content(file_name)
              expect(page).to have_content(file_content)
            end
          end
        end
      end

      context 'when git-lfs commit' do
        it "new Git LFS data is viewable in UI on secondary Geo sites" do
          key_title = "Geo SSH LFS #{Time.now.to_f}"
          file_content = 'The rendered file could not be displayed because it is stored in LFS.'
          project = nil

          QA::Flow::Login.while_signed_in(address: :geo_primary) do
            # Create a new SSH key for the user
            key = create(:ssh_key, title: key_title)

            # Create a new Project
            project = create(:project, name: 'geo-project', description: 'Geo test project for SSH LFS push')

            # Perform a git push over SSH directly to the primary
            push = Resource::Repository::ProjectPush.fabricate! do |push|
              push.use_lfs = true
              push.ssh_key = key
              push.project = project
              push.file_name = file_name
              push.file_content = "# #{file_content}"
              push.commit_message = 'Add README.md'
            end

            expect(push.output).to match(/Locking support detected on remote/)

            # Validate git push worked and file exists with content
            push.project.visit!
            Page::Project::Show.perform do |show|
              show.wait_for_repository_replication

              expect(page).to have_content(file_name)
              expect(page).to have_content(file_content)
            end
          end

          QA::Runtime::Logger.debug('*****Visiting the secondary Geo site*****')

          QA::Flow::Login.while_signed_in(address: :geo_secondary) do
            # Ensure project is displayed
            Page::Main::Menu.perform(&:go_to_projects)
            Page::Dashboard::Projects.perform do |dashboard|
              dashboard.wait_for_project_replication(project.name)
              dashboard.go_to_project(project.name)
            end

            # Validate the content looks the same as on the primary site
            Page::Project::Show.perform do |show|
              show.wait_for_repository_replication_with(file_name)

              expect(page).to have_content(file_name)
              expect(page).to have_content(file_content)
            end
          end
        end
      end
    end
  end
end
