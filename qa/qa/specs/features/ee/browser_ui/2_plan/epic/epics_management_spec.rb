# frozen_string_literal: true

module QA
  # Add :smoke back once proven reliable
  RSpec.describe 'Plan', feature_category: :portfolio_management do
    describe 'Epics Management' do
      let(:group) { create(:group, name: "group-to-test-epics-#{SecureRandom.hex(4)}") }

      before do
        Flow::Login.sign_in
      end

      it 'creates an epic' do
        epic_title = 'Epic created via GUI'

        EE::Resource::WorkItemEpic.fabricate_via_browser_ui! do |epic|
          epic.group = group
          epic.title = epic_title
        end

        expect(page).to have_content(epic_title)
      end

      it 'creates a confidential epic' do
        epic_title = 'Confidential epic created via GUI'

        EE::Resource::WorkItemEpic.fabricate_via_browser_ui! do |epic|
          epic.group = group
          epic.title = epic_title
          epic.confidential = true
        end

        expect(page).to have_content(epic_title)
        expect(page).to have_css('[data-testid="confidential-badge-text"]', text: 'Confidential')
      end

      context 'when resources created via API' do
        let(:issue) { create_issue_resource }
        let(:epic) { create(:work_item_epic, group: issue.project.group, title: 'Work Item Epic created via API') }

        context 'when visit epic first' do
          before do
            epic.visit!
          end

          it 'adds/removes issue to/from epic' do
            EE::Page::Group::WorkItem::Epic::Show.perform do |show|
              show.add_child_issue_to_epic(issue)

              expect(show).to have_child_issue_item

              show.remove_child_issue_from_epic(issue)

              expect(show).to have_no_child_issue_item
            end
          end

          it 'comments on epic' do
            comment = 'My Epic Comment'
            EE::Page::Group::WorkItem::Epic::Show.perform do |show|
              show.comment(comment)

              expect(show).to have_comment(comment)
            end
          end

          it 'closes and reopens an epic' do
            EE::Page::Group::WorkItem::Epic::Show.perform do |show|
              show.close_epic

              expect { show.has_system_note?('closed') }.to eventually_be_truthy.within(max_duration: 60),
                "Expected 'closed' system note but it did not appear."

              show.reopen_epic

              expect { show.has_system_note?('opened') }.to eventually_be_truthy.within(max_duration: 60),
                "Expected 'opened' system note but it did not appear."
            end
          end
        end

        it 'adds/removes issue to/from epic using quick actions' do
          issue.visit!

          Page::Project::WorkItem::Show.perform do |show|
            show.wait_for_child_items_to_load
            show.comment("/set_parent #{issue.project.group.web_url}/-/epics/#{epic.iid}")
            show.comment("/remove_parent")
          end

          epic.visit!

          EE::Page::Group::WorkItem::Epic::Show.perform do |show|
            expect(show).to have_system_note(/(added)([\w\-# ]+)(issue)/)
            expect(show).to have_system_note('removed')
          end
        end

        def create_issue_resource
          project = create(:project, :private, name: 'project-for-issues', description: 'project for adding issues')

          create(:issue, project: project)
        end
      end
    end
  end
end
