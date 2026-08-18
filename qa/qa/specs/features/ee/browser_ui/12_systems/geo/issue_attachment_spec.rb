# frozen_string_literal: true

module QA
  RSpec.describe 'Systems', :orchestrated, :geo, feature_category: :geo_replication do
    describe 'issue attachment' do
      let(:file_to_attach) { Runtime::Path.fixture('designs', 'banana_sample.gif') }
      let(:project) do
        create(:project, name: 'project-for-issues', description: 'project for adding issues')
      end

      let(:issue) { create(:issue, title: 'My Geo issue', project: project) }

      it 'is viewable on secondary Geo sites' do
        QA::Flow::Login.while_signed_in(address: :geo_primary) do
          issue.visit!

          Page::Project::WorkItem::Show.perform do |show|
            show.comment('See attached banana for scale', attachment: file_to_attach)
          end
        end

        QA::Runtime::Logger.debug('Visiting the secondary Geo site')

        QA::Flow::Login.while_signed_in(address: :geo_secondary) do
          Page::Main::Menu.perform(&:go_to_projects)

          Page::Dashboard::Projects.perform do |dashboard|
            dashboard.wait_for_project_replication(project.name)

            dashboard.go_to_project(project.name)
          end

          Page::Project::Menu.act { go_to_work_items }

          Page::Project::WorkItem::Index.perform do |index|
            index.wait_for_issue_replication(issue)
          end

          image_url = find('a[href$="banana_sample.gif"]')[:href]

          Page::Project::WorkItem::Show.perform do |show|
            found = show.wait_for_attachment_replication(image_url)

            expect(found).to be_truthy
          end
        end
      end
    end
  end
end
