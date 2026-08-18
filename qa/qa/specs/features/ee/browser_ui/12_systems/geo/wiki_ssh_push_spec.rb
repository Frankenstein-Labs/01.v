# frozen_string_literal: true

module QA
  RSpec.describe 'Systems', :orchestrated, :geo, feature_category: :geo_replication do
    describe 'GitLab wiki SSH push' do
      key = nil

      after do
        key&.remove_via_api!
      end

      context 'when wiki commit' do
        it 'new Git data is viewable in UI on secondary Geo sites' do
          wiki_content = 'Wikis should appear on secondary Geo sites after pushing via SSH to the primary'
          push_content = 'This is from the Geo wiki push via SSH!'
          project = nil

          QA::Flow::Login.while_signed_in(address: :geo_primary) do
            # Create a new SSH key
            key = create(:ssh_key, title: "Geo wiki SSH #{Time.now.to_f}", expires_at: Date.today + 2)

            # Create a new project and wiki
            project = create(:project, name: 'geo-wiki-ssh-project', description: 'Geo project for wiki SSH spec')

            wiki = create(:project_wiki_page, project: project, title: 'Geo Wiki test', content: wiki_content)
            wiki.visit!
            validate_content(wiki_content)

            # Perform a git push over SSH directly to the primary
            pushed_wiki = Resource::Repository::WikiPush.fabricate! do |push|
              push.ssh_key = key
              push.wiki = wiki
              push.file_name = 'Home.md'
              push.file_content = push_content
              push.commit_message = 'Update Home.md'
            end

            pushed_wiki.visit!
            validate_content(push_content)
          end

          QA::Runtime::Logger.debug('*****Visiting the secondary Geo site*****')

          QA::Flow::Login.while_signed_in(address: :geo_secondary) do
            Page::Main::Menu.perform(&:go_to_projects)

            Page::Dashboard::Projects.perform do |dashboard|
              dashboard.wait_for_project_replication(project.name)
              dashboard.go_to_project(project.name)
            end

            # Validate git push worked and new content is visible
            Page::Project::Menu.perform(&:go_to_wiki)

            Page::Project::Wiki::Show.perform do |show|
              show.wait_for_repository_replication_with(push_content)
              show.refresh
            end

            validate_content(push_content)
          end
        end
      end

      def validate_content(content)
        Page::Project::Wiki::Show.perform do |show|
          expect(show).to have_content(content)
        end
      end
    end
  end
end
