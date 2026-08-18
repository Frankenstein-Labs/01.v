# frozen_string_literal: true

module QA
  RSpec.describe 'Systems', :orchestrated, :geo, feature_category: :geo_replication do
    describe 'GitLab wiki HTTP push' do
      context 'when wiki commit' do
        it 'new Git data is viewable in UI on secondary Geo sites' do
          wiki_content = 'Wikis should appear on secondary Geo sites after pushing via HTTP to the primary'
          push_content = 'This is from the Geo wiki push!'
          project = nil

          # Create new wiki and push wiki commit
          QA::Flow::Login.while_signed_in(address: :geo_primary) do
            project = create(:project, name: 'geo-wiki-http-project', description: 'Geo project for wiki test')

            wiki = create(:project_wiki_page, project: project, title: 'Geo Wiki test', content: wiki_content)
            wiki.visit!
            expect(page).to have_content(wiki_content)

            push = Resource::Repository::WikiPush.fabricate! do |push|
              push.wiki = wiki
              push.file_name = 'Home.md'
              push.file_content = push_content
              push.commit_message = 'Update Home.md'
            end

            push.visit!
            expect(page).to have_content(push_content)
          end

          # Validate that wiki content is accessible on the secondary Geo site
          QA::Runtime::Logger.debug('Visiting the secondary Geo site')

          QA::Flow::Login.while_signed_in(address: :geo_secondary) do
            Page::Main::Menu.perform(&:go_to_projects)

            Page::Dashboard::Projects.perform do |dashboard|
              dashboard.wait_for_project_replication(project.name)
              dashboard.go_to_project(project.name)
            end

            Page::Project::Menu.perform(&:go_to_wiki)

            Page::Project::Wiki::Show.perform do |show|
              expect(show).to have_content(push_content)
            end
          end
        end
      end
    end
  end
end
