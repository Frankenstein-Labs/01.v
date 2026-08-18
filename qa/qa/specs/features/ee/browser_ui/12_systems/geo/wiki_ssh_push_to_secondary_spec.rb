# frozen_string_literal: true

module QA
  RSpec.describe 'Systems', :orchestrated, :geo, feature_category: :geo_replication do
    describe 'GitLab wiki SSH push to secondary' do
      wiki_content = 'Wikis should appear on secondary Geo sites after pushing via SSH to a secondary'
      push_content = 'This is from the Geo wiki push via SSH to secondary!'
      wiki = nil
      key = nil
      project = nil

      before do
        QA::Flow::Login.while_signed_in(address: :geo_primary) do
          # Create a new SSH key
          key = create(:ssh_key, title: "Geo wiki SSH to 2nd #{Time.now.to_f}", expires_at: Date.today + 2)

          # Create a new project and wiki
          project = create(:project, name: 'geo-wiki-ssh2-project', description: 'Geo project for wiki SSH spec')

          wiki = create(:project_wiki_page, project: project, title: 'Geo Wiki test', content: wiki_content)
          wiki.visit!
          validate_content(wiki_content)
        end
      end

      after do
        key&.remove_via_api!
      end

      it 'proxies wiki commit to primary site and is viewable in UI on secondary Geo sites' do
        QA::Runtime::Logger.debug('*****Visiting the secondary Geo site*****')

        QA::Flow::Login.while_signed_in(address: :geo_secondary) do
          # Ensure the SSH key is accessible on the secondary site
          expect(key).to be_accessible_on_secondary

          Page::Main::Menu.perform(&:go_to_projects)

          Page::Dashboard::Projects.perform do |dashboard|
            dashboard.wait_for_project_replication(project.name)
            dashboard.go_to_project(project.name)
          end

          Page::Project::Menu.perform(&:go_to_wiki)

          # Grab the SSH URI for the secondary site and store as 'secondary_location'
          Page::Project::Wiki::Show.perform do |show|
            show.wait_for_repository_replication
            show.click_clone_repository
          end

          secondary_location = Page::Project::Wiki::GitAccess.perform do |git_access|
            git_access.choose_repository_clone_ssh
            git_access.repository_location
          end

          # Perform a git push over SSH to the secondary site
          push = Resource::Repository::WikiPush.fabricate! do |push|
            push.ssh_key = key
            push.wiki = wiki
            push.repository_ssh_uri = secondary_location.uri
            push.file_name = 'Home.md'
            push.file_content = push_content
            push.commit_message = 'Update Home.md'
          end

          # Validate git push worked and new content is visible
          push.visit!

          Page::Project::Wiki::Show.perform do |show|
            show.wait_for_repository_replication_with(push_content)
            show.refresh
          end

          validate_content(push_content)
        end
      end

      private

      def validate_content(content)
        Page::Project::Wiki::Show.perform do |show|
          expect(show).to have_content(content)
        end
      end
    end
  end
end
