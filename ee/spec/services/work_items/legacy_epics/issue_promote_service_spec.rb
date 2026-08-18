# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::IssuePromoteService, :aggregate_failures, feature_category: :portfolio_management do
  let(:epic) { Epic.last }
  let(:current_user) { user }

  let_it_be(:user) { create(:user) }
  let_it_be(:ancestor) { create(:group) }
  let_it_be(:group) { create(:group, parent: ancestor, developers: [user]) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:label1) { create(:group_label, group: group) }
  let_it_be(:label2) { create(:label, project: project) }
  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:description) { 'simple description' }
  let_it_be_with_refind(:issue) do
    create(
      :issue,
      project: project,
      labels: [label1, label2],
      milestone: milestone,
      description: description,
      weight: 3
    )
  end

  let_it_be_with_refind(:parent_epic) do
    create(:epic, group: group)
  end

  subject(:service) { described_class.new(container: issue.project, current_user: current_user) }

  describe '#execute' do
    context 'when epics are not enabled' do
      it 'raises a permission error' do
        group.add_developer(user)

        expect { service.execute(issue) }
          .to raise_error(::WorkItems::LegacyEpics::IssuePromoteService::PromoteError, /permissions/)
      end
    end

    context 'when epics and subepics are enabled' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      context 'when a user can not promote the issue' do
        let(:current_user) { create(:user) }

        it 'raises a permission error' do
          expect { service.execute(issue) }
            .to raise_error(::WorkItems::LegacyEpics::IssuePromoteService::PromoteError, /permissions/)
        end
      end

      context 'when a user can promote the issue' do
        let_it_be(:new_group) { create(:group, developers: [user]) }

        context 'when an issue does not belong to a group' do
          it 'raises an error' do
            other_issue = create(:issue, project: create(:project))

            expect { service.execute(other_issue) }
              .to raise_error(::WorkItems::LegacyEpics::IssuePromoteService::PromoteError, /group/)
          end
        end

        context 'with published event' do
          it 'publishes an WorkItemCreatedEvent' do
            expect { service.execute(issue) }
              .to publish_event(WorkItems::WorkItemCreatedEvent)
                    .with({ id: an_instance_of(Integer), namespace_id: group.id })
          end
        end

        context 'when promoting issue' do
          let_it_be(:issue_mentionable_note) do
            create(:note, noteable: issue, author: user, project: project,
              note: "note with mention #{user.to_reference}")
          end

          let_it_be(:issue_note) do
            create(:note, noteable: issue, author: user, project: project, note: "note without mention")
          end

          let(:new_description) { "New description" }

          before do
            issue.update!(description: new_description)
            service.execute(issue)
          end

          it 'syncs work item and epic correctly' do
            expect(Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item).attributes).to be_empty
          end

          it 'creates a new epic with correct attributes' do
            expect(epic.title).to eq(issue.title)
            expect(epic.description).to eq(issue.description)
            expect(epic.author).to eq(user)
            expect(epic.group).to eq(group)
            expect(epic.parent).to be_nil
          end

          it 'copies group labels assigned to the issue' do
            expect(epic.labels).to eq([label1])
          end

          it 'creates a system note on the issue' do
            expect(issue.notes.last.note).to eq("promoted to epic #{epic.to_reference(project)}")
          end

          it 'creates a system note on the epic' do
            expect(epic.notes.last.note).to eq("promoted from issue #{issue.to_reference(group)}")
          end

          it 'closes the original issue' do
            expect(issue.reload).to be_closed
          end

          it 'marks the old issue as promoted' do
            expect(issue.work_item_transition.promoted?).to be(true)
            expect(issue.reload.promoted_to_epic).to eq(epic)
            expect(issue.work_item_transition.reload.promoted_to_epic).to eq(epic)
          end

          context 'when issue description has mentions and has notes with mentions' do
            let(:new_description) { "description with mention to #{user.to_reference}" }

            it 'only saves user mentions with actual mentions' do
              work_item = epic.sync_object

              expect(work_item.user_mentions.find_by(note_id: nil).mentioned_users_ids).to match_array([user.id])
              expect(work_item.user_mentions.where.not(note_id: nil).first.mentioned_users_ids)
                .to match_array([user.id])
              expect(work_item.user_mentions.where.not(note_id: nil).count).to eq 1
              expect(work_item.user_mentions.count).to eq 2
            end
          end

          context 'when issue description has an attachment' do
            let(:image_uploader) { build(:file_uploader, container: project) }
            let(:new_description) { "A description and image: #{image_uploader.markdown_link}" }

            it 'copies the description, rewriting the attachment' do
              new_image_uploader = Upload.last.retrieve_uploader

              expect(new_image_uploader.markdown_link).not_to eq(image_uploader.markdown_link)
              expect(epic.description).to eq("A description and image: #{new_image_uploader.markdown_link}")
            end
          end
        end

        context 'when issue has resource label events' do
          let!(:label_event1) { create(:resource_label_event, label: label1, issue: issue, user: user) }
          let!(:label_event2) { create(:resource_label_event, label: label2, issue: issue, user: user) }

          it 'creates new label events on the epic that do not reference the original issue' do
            expect do
              service.execute(issue)
            end.to change { ResourceLabelEvent.count }.by(2)

            expect(issue.resource_label_events.count).to eq(2)
            # The ResourceLabelEvent gets written to the WorkItem
            expect(ResourceLabelEvent.where(issue: epic.issue_id).count).to eq(2)
            expect(ResourceLabelEvent.where(epic: epic.id).count).to eq(0)
          end
        end

        context 'when issue has resource state event' do
          let_it_be(:issue_event) { create(:resource_state_event, issue: issue) }

          it 'does not raise error' do
            expect { service.execute(issue) }.not_to raise_error
          end

          it 'creates a close state event for promoted issue' do
            # promote issue to epic also copies over existing issue state resource events to the epic
            # so in this case we have an existing resource event defined above and one that we create
            # for issue close event, which we are not copying over
            expect { service.execute(issue) }.to change { ResourceStateEvent.count }.by(2).and(
              change { ResourceStateEvent.where(issue_id: issue).count }.by(1)
            )
          end

          it 'promotes issue successfully' do
            epic = service.execute(issue)

            resource_state_event = epic.sync_object.resource_state_events.first
            expect(epic.title).to eq(issue.title)
            expect(issue.reload.promoted_to_epic).to eq(epic)
            expect(resource_state_event.issue_id).to eq(epic.sync_object.id)
            expect(resource_state_event.epic_id).to be_nil
            expect(resource_state_event.state).to eq(issue_event.state)
          end
        end

        context 'when promoting issue to a different group' do
          it 'creates a new epic with correct attributes' do
            epic = service.execute(issue, new_group)

            expect(issue.reload.promoted_to_epic_id).to eq(epic.id)
            expect(epic.title).to eq(issue.title)
            expect(epic.description).to eq(issue.description)
            expect(epic.author).to eq(user)
            expect(epic.group).to eq(new_group)
            expect(epic.parent).to be_nil
          end
        end

        context 'when promotion would reach the depth limit' do
          let_it_be(:epic_issue) do
            create(:epic_issue, :with_parent_link, epic: parent_epic, issue: issue)
          end

          before do
            epic_type = build(:work_item_system_defined_type, :epic)

            allow(WorkItems::TypesFramework::SystemDefined::HierarchyRestriction).to receive(:find_by).with(
              parent_type_id: epic_type.id,
              child_type_id: epic_type.id
            ).and_return(
              instance_double(
                WorkItems::TypesFramework::SystemDefined::HierarchyRestriction,
                maximum_depth: 0,
                parent_type_id: epic_type.id,
                child_type_id: epic_type.id
              )
            )
          end

          it 'rejects promoting an issue to an epic' do
            expect { service.execute(issue) }
              .to not_change { Epic.count }
              .and not_change { WorkItem.count }
              .and raise_error(::WorkItems::LegacyEpics::IssuePromoteService::PromoteError, /reached maximum depth/)
          end
        end

        context 'when an issue belongs to an epic' do
          let_it_be(:epic_issue) do
            create(:epic_issue, :with_parent_link, epic: parent_epic, issue: issue)
          end

          shared_examples 'successfully promotes issue to epic' do
            it 'creates a new epic with correct attributes' do
              epic = service.execute(issue, new_group)

              expect(issue.reload.promoted_to_epic_id).to eq(epic.id)
              expect(epic.title).to eq(issue.title)
              expect(epic.description).to eq(issue.description)
              expect(epic.author).to eq(user)
              expect(epic.group).to eq(new_group)
              expect(epic.reload.parent).to eq(parent_epic)
              expect(epic.work_item.work_item_parent).to eq(parent_epic.work_item)
            end
          end

          it_behaves_like 'successfully promotes issue to epic' do
            let(:new_group) { group }
          end

          context 'when promoting issue to a different group' do
            let_it_be(:new_group) { create(:group) }

            before_all do
              new_group.add_developer(user)
            end

            it_behaves_like 'successfully promotes issue to epic'
          end

          context 'when promoting issue to a different group in the same hierarchy' do
            context 'when the group is a descendant group' do
              let_it_be(:issue_group) { create(:group, parent: group) }

              before_all do
                new_group.add_developer(user)
              end

              it_behaves_like 'successfully promotes issue to epic'
            end

            context 'when the group is an ancestor group' do
              let_it_be(:new_group) { ancestor }

              before_all do
                new_group.add_developer(user)
              end

              it_behaves_like 'successfully promotes issue to epic'
            end
          end

          context 'when issue and epic are confidential' do
            before do
              issue.update_attribute(:confidential, true)
              parent_epic.update_attribute(:confidential, true)
              parent_epic.work_item.update_attribute(:confidential, true)
            end

            it 'promotes issue to epic' do
              epic = service.execute(issue, group)

              expect(issue.reload.promoted_to_epic_id).to eq(epic.id)
              expect(epic).to be_confidential
              expect(epic.work_item).to be_confidential
              expect(epic.parent).to eq(parent_epic)
            end
          end

          context 'when subepics are disabled' do
            before do
              stub_licensed_features(epics: true, subepics: false)
            end

            it 'does not promote to epic and raises error' do
              expect { service.execute(issue, new_group) }
                .to raise_error(::WorkItems::LegacyEpics::IssuePromoteService::PromoteError, /not supported/)

              expect(issue.reload.state).to eq("opened")
              expect(issue.promoted_to_epic_id).to be_nil
            end
          end
        end

        context 'when issue was already promoted' do
          it 'raises error' do
            epic = create(:epic, group: group)
            issue.update!(promoted_to_epic_id: epic.id)

            expect { service.execute(issue) }
              .to raise_error(::WorkItems::LegacyEpics::IssuePromoteService::PromoteError, /already promoted/)
          end
        end

        context 'when issue has notes' do
          before do
            issue.reload
          end

          it 'copies all notes' do
            discussion = create(:discussion_note_on_issue, noteable: issue, project: issue.project)

            epic = service.execute(issue)
            expect(epic.notes.count).to eq(issue.notes.count)
            expect(epic.notes.where(discussion_id: discussion.discussion_id).count).to eq(0)
            expect(issue.notes.where(discussion_id: discussion.discussion_id).count).to eq(1)
          end
        end

        context 'on other issue types' do
          shared_examples_for 'raising error' do
            before do
              issue.update!(work_item_type_id: build(:work_item_system_defined_type, issue_type).id)
            end

            it 'raises error' do
              expect { service.execute(issue) }
                .to raise_error(::WorkItems::LegacyEpics::IssuePromoteService::PromoteError, /is not supported/)
            end
          end

          context 'on an incident' do
            let(:issue_type) { :incident }

            it_behaves_like 'raising error'
          end

          context 'on a test case' do
            let(:issue_type) { :test_case }

            it_behaves_like 'raising error'
          end
        end

        context 'for synced work items' do
          let_it_be(:epic_issue) do
            create(:epic_issue, :with_parent_link, epic: parent_epic, issue: issue)
          end

          subject(:promote_issue) { described_class.new(container: issue.project, current_user: user).execute(issue) }

          it 'creates a work item' do
            expect { promote_issue }.to change { issue.project.group.work_items.count }.by(1)
          end

          context 'with synced data' do
            it 'keeps labels and hierarchy' do
              expect { promote_issue }.to change { LabelLink.where(target_type: 'Issue').count }.by(1)
                .and not_change { LabelLink.where(target_type: 'Epic').count }

              epic = promote_issue
              expect(epic.parent).to eq(parent_epic)
              expect(epic.work_item.work_item_parent).to eq(parent_epic.work_item)
            end
          end
        end

        context 'for milestones' do
          let_it_be(:project_milestone) { create(:milestone, project: project) }

          it 'successfully retains the group level Milestone on the new epic' do
            epic = service.execute(issue, group)
            expect(WorkItem.find(epic.issue_id).milestone).to eq(milestone)
          end

          it 'does not retain project level milestones on the new epic' do
            issue.update!(milestone: project_milestone)

            epic = service.execute(issue, group)
            expect(WorkItem.find(epic.issue_id).milestone).to be_nil
          end
        end
      end
    end
  end
end
