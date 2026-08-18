# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/SpecFilePathFormat -- all Epics::UpdateService calls go through adapter service
RSpec.describe WorkItems::LegacyEpics::UpdateService, feature_category: :portfolio_management do
  include LegacyEpicsHelper
  let_it_be_with_refind(:group) { create(:group, :internal) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:epic) { create(:epic, group: group) }

  describe '#execute' do
    before do
      stub_licensed_features(epics: true, subepics: true, epic_colors: true)
      group.add_maintainer(user) # rubocop:disable RSpec/BeforeAllRoleAssignment -- role assignment needed per test to avoid state pollution
    end

    def find_note(starting_with)
      epic.notes.find do |note|
        note && note.note.start_with?(starting_with)
      end
    end

    def find_notes(action)
      epic
        .notes
        .joins(:system_note_metadata)
        .where(system_note_metadata: { action: action })
    end

    def update_epic(opts)
      described_class.new(group: group, current_user: user, params: opts).execute(epic)
    end

    it_behaves_like 'issuable update service updating last_edited_at values' do
      let(:issuable) { epic }
      subject(:update_issuable) { update_epic(update_params) }
    end

    context 'when updating multiple values' do
      let(:opts) do
        {
          title: 'New title',
          description: 'New description',
          start_date_fixed: '2017-01-09',
          start_date_is_fixed: true,
          due_date_fixed: '2017-10-21',
          due_date_is_fixed: true,
          state_event: 'close',
          confidential: true
        }
      end

      it 'updates the epic correctly' do
        update_epic(opts)

        expect(epic).to be_valid
        expect(epic).to have_attributes(
          title: 'New title',
          description: 'New description',
          start_date_fixed: Date.strptime('2017-01-09'),
          due_date_fixed: Date.strptime('2017-10-21'),
          start_date_is_fixed: true,
          due_date_is_fixed: true
        )
        expect(epic).to be_confidential
        expect(epic).to be_closed
      end
    end

    context 'when title has changed' do
      it 'creates system note about title change' do
        expect { update_epic(title: 'New title') }.to change { Note.count }.from(0).to(1)

        note = Note.last

        expect(note.note).to start_with('<p>changed title')
        expect(note.noteable_id).to eq(epic.issue_id)
      end
    end

    context 'when description has changed' do
      it 'creates system note about description change' do
        expect { update_epic(description: 'New description') }.to change { Note.count }.from(0).to(1)

        note = Note.last

        expect(note.note).to start_with('changed the description')
        expect(note.noteable_id).to eq(epic.issue_id)
      end

      it 'triggers GraphQL description updated subscription' do
        expect(GraphqlTriggers).to receive(:issuable_description_updated).with(epic.work_item).and_call_original

        update_epic(description: 'updated description')
      end

      it 'creates description version for work items only' do
        update_epic(description: 'New description')

        expect(epic.reload.own_description_versions.count).to eq(0)
        expect(epic.sync_object.reload.own_description_versions.count).to eq(2)
      end
    end

    context 'when description is not changed' do
      it 'does not trigger GraphQL description updated subscription' do
        expect(GraphqlTriggers).not_to receive(:issuable_description_updated)

        update_epic(title: 'updated title')
      end
    end

    context 'when updating todos' do
      before do
        group.update!(visibility: Gitlab::VisibilityLevel::PUBLIC)
      end

      context 'when creating todos' do
        let(:mentioned1) { create(:user) }
        let(:mentioned2) { create(:user) }

        before do
          epic.update!(description: "FYI: #{mentioned1.to_reference}")
          epic.work_item.update!(description: "FYI: #{mentioned1.to_reference}")
        end

        it 'creates todos for only newly mentioned users' do
          expect do
            update_epic(description: "FYI: #{mentioned1.to_reference} #{mentioned2.to_reference}")
          end.to change { Todo.count }.by(1)
        end
      end

      context 'when adding a label' do
        let(:label) { create(:group_label, group: group) }
        let(:user2) { create(:user) }
        let!(:todo1) do
          create(:todo, :mentioned, :pending,
            target: epic,
            group: group,
            project: nil,
            author: user,
            user: user)
        end

        let!(:todo2) do
          create(:todo, :mentioned, :pending,
            target: epic,
            group: group,
            project: nil,
            author: user2,
            user: user2)
        end

        subject(:add_label_to_epic) { update_epic(label_ids: [label.id]) }

        before do
          group.add_developer(user) # rubocop:disable RSpec/BeforeAllRoleAssignment -- role assignment needed per test to avoid state pollution
        end

        it 'marks todo as done for a user who added a label' do
          add_label_to_epic

          expect(todo1.reload.state).to eq('done')
        end

        it 'does not mark todos as done for other users' do
          add_label_to_epic

          expect(todo2.reload.state).to eq('pending')
        end

        context 'when mentioning a group in epic description' do
          let_it_be(:mentioned1) { create(:user, developer_of: group) }
          let_it_be(:mentioned2) { create(:user) }

          before do
            epic.update!(description: "FYI: #{group.to_reference}")
            epic.work_item.update!(description: "FYI: #{group.to_reference}")
          end

          context 'when the group is public' do
            before do
              group.update!(visibility: Gitlab::VisibilityLevel::PUBLIC)
            end

            it 'creates todos for only newly mentioned users' do
              expect do
                update_epic(description: "FYI: #{mentioned1.to_reference} #{mentioned2.to_reference}")
              end.to change { Todo.count }.by(1)
            end
          end

          context 'when the group is private' do
            before do
              group.update!(visibility: Gitlab::VisibilityLevel::PRIVATE)
            end

            it 'creates todos for only newly mentioned users that are group members' do
              expect do
                update_epic(description: "FYI: #{mentioned1.to_reference} #{mentioned2.to_reference}")
              end.to change { Todo.count }
            end
          end
        end
      end

      context 'when Epic has tasks' do
        before do
          update_epic(description: "- [ ] Task 1\n- [ ] Task 2")
        end

        it { expect(epic.tasks?).to be(true) }

        it_behaves_like 'updating a single task' do
          def update_issuable(opts)
            described_class.new(group: group, current_user: user, params: opts).execute(epic)
          end
        end

        context 'when tasks are marked as completed' do
          it 'creates system note about task status change' do
            update_epic(description: "- [x] Task 1\n- [X] Task 2")

            note1 = find_note('marked the checklist item **Task 1** as completed')
            note2 = find_note('marked the checklist item **Task 2** as completed')

            expect(note1).not_to be_nil
            expect(note2).not_to be_nil

            description_notes = find_notes('description')
            expect(description_notes.length).to eq(1)
          end
        end

        context 'when tasks are marked as incomplete' do
          before do
            update_epic(description: "- [x] Task 1\n- [X] Task 2")
          end

          it 'creates system note about task status change' do
            update_epic(description: "- [ ] Task 1\n- [ ] Task 2")

            note1 = find_note('marked the checklist item **Task 1** as incomplete')
            note2 = find_note('marked the checklist item **Task 2** as incomplete')

            expect(note1).not_to be_nil
            expect(note2).not_to be_nil

            description_notes = find_notes('description')
            expect(description_notes.length).to eq(1)
          end
        end
      end

      context 'when updating labels' do
        let(:label_a) { create(:group_label, title: 'a', group: group) }
        let(:label_b) { create(:group_label, title: 'b', group: group) }
        let(:label_c) { create(:group_label, title: 'c', group: group) }
        let(:label_locked) { create(:group_label, title: 'locked', group: group, lock_on_merge: true) }
        let(:issuable) { epic.work_item }

        it_behaves_like 'updating issuable labels'
        it_behaves_like 'keeps issuable labels sorted after update'
        it_behaves_like 'broadcasting issuable labels updates'

        def update_issuable(update_params)
          update_epic(update_params)
        end
      end

      context 'with quick actions in the description' do
        before do
          stub_licensed_features(epics: true, subepics: true)
          group.add_developer(user) # rubocop:disable RSpec/BeforeAllRoleAssignment -- role assignment needed per test to avoid state pollution
        end

        context 'for /label' do
          let(:label) { create(:group_label, group: group) }

          it 'adds labels to the epic' do
            update_epic(description: "/label ~#{label.name}")

            expect(epic.label_ids).to contain_exactly(label.id)
          end
        end

        context 'for /set_parent' do
          it 'assigns parent epic' do
            parent_epic = create(:epic, group: epic.group)

            update_epic(description: "/set_parent #{parent_epic.to_reference}")

            expect(epic.parent).to eq(parent_epic)
          end

          context 'when parent epic cannot be assigned' do
            it 'does not update parent epic' do
              other_group = create(:group, :private)
              parent_epic = create(:epic, group: other_group)

              update_epic(description: "/parent_epic #{parent_epic.to_reference(group)}")

              expect(epic.parent).to be_nil
            end
          end
        end

        context 'for /add_child' do
          it 'sets a child epic' do
            child_epic = create(:epic, group: group)

            update_epic(description: "/add_child #{child_epic.to_reference}")

            expect(epic.reload.children).to include(child_epic)
          end

          context 'when child epic cannot be assigned' do
            it 'does not set child epic' do
              other_group = create(:group, :private)
              child_epic = create(:epic, group: other_group)

              update_epic(description: "/child_epic #{child_epic.to_reference(group)}")
              expect(epic.reload.children).to be_empty
            end
          end
        end

        it_behaves_like 'issuable record does not run quick actions when not editing description' do
          let(:label) { create(:group_label, group: group) }
          let(:assignee) { create(:user, maintainer_of: group) }
          let(:epic) { create(:epic, group: group, description: old_description) }
          let(:updated_issuable) { update_epic(params) }
        end
      end

      context 'when updating parent' do
        let(:new_parent) { create(:epic, group: group) }

        subject(:update_epic_parent) { update_epic(parent: new_parent) }

        context 'when user cannot update parent' do
          shared_examples 'updates epic without changing parent' do
            it 'does not change parent' do
              expect { update_epic_parent }.not_to change { epic.parent }
            end
          end

          context 'when subepics are disabled' do
            before do
              stub_licensed_features(epics: true, subepics: false)
            end

            it_behaves_like 'updates epic without changing parent'
          end

          context 'when user lacks permissions' do
            let_it_be_with_reload(:user) { create(:user) }

            before do
              new_parent.update!(confidential: true)
              group.add_guest(user) # rubocop:disable RSpec/BeforeAllRoleAssignment -- role assignment needed per test to avoid state pollution
            end

            it_behaves_like 'updates epic without changing parent'

            context 'when using parent_id' do
              subject(:update_epic_parent_by_id) { update_epic(parent_id: new_parent.id) }

              it 'does not change parent' do
                expect { update_epic_parent_by_id }.not_to change { epic.parent }
              end
            end
          end
        end

        context 'when user can update parent' do
          it 'creates system notes' do
            expect { update_epic_parent }.to change { epic.parent }.from(nil).to(new_parent)
                                                    .and change { Note.count }.by(2)

            child_ref = epic.work_item.to_reference(group)
            new_ref = new_parent.work_item.to_reference(group)

            epic.reload
            expect(epic.notes.first.note).to eq("added #{new_ref} as parent item")
            expect(new_parent.notes.first.note).to eq("added #{child_ref} as child item")
          end

          context 'when parent is already present' do
            let(:existing_parent) { create(:epic, group: group) }

            before do
              assign_epic_parent(epic, existing_parent)
            end

            it 'changes parent and creates system notes' do
              expect { update_epic_parent }.to change { epic.parent }.from(existing_parent).to(new_parent)
                                                      .and change { Note.count }.by(3)

              child_ref = epic.work_item.to_reference(group)
              new_ref = new_parent.work_item.to_reference(group)

              epic.reload
              expect(existing_parent.notes.last.note).to eq("moved child epic #{child_ref} to #{new_ref}")
              expect(epic.notes.first.note).to eq("added #{new_ref} as parent item")
              expect(new_parent.notes.first.note).to eq("added #{child_ref} as child item")
            end

            context 'when removing parent' do
              subject(:remove_epic_parent) { update_epic(parent: nil) }

              it 'removes parent and creates system notes' do
                expect { remove_epic_parent }.to change { epic.parent }.from(existing_parent).to(nil)
                                                      .and change { Note.count }.by(2)

                child_ref = epic.work_item.to_reference(group)
                existing_ref = existing_parent.work_item.to_reference(group)

                epic.reload
                expect(epic.notes.first.note).to eq("removed parent item #{existing_ref}")
                expect(existing_parent.notes.first.note).to eq("removed child item #{child_ref}")
              end
            end
          end
        end
      end

      context 'when there is a work item sync' do
        let_it_be(:group, freeze: false) { create(:group) }
        let_it_be(:labels) { create_pair(:group_label, group: group) }

        context 'when epic has a synced work item' do
          let_it_be_with_reload(:epic) { create(:epic, :with_synced_work_item, group: group) }
          let(:work_item) { epic.work_item }

          context 'when updating multiple values' do
            let_it_be(:synced_parent_work_item) { create(:work_item, :epic, namespace: group) }
            let_it_be(:parent_epic) { create(:epic, group: group, issue_id: synced_parent_work_item.id) }
            let_it_be(:start_date) { Date.new(2024, 1, 1) }
            let_it_be(:due_date) { Date.new(2024, 1, 31) }

            context 'when changes are valid' do
              let(:opts) do
                {
                  title: 'New title',
                  description: 'New description',
                  confidential: true,
                  color: '#CC0000',
                  parent: parent_epic,
                  start_date_is_fixed: true,
                  start_date_fixed: start_date,
                  due_date_is_fixed: true,
                  due_date_fixed: due_date
                }
              end

              subject(:update_synced_epic) { update_epic(opts) }

              it_behaves_like 'syncs all data from an epic to a work item', notes_on_work_item: true

              context 'when updating rolledup dates' do
                let(:opts) { { start_date_is_fixed: false, due_date_is_fixed: false } }

                context 'with issue milestone date roll up' do
                  let_it_be(:milestone) do
                    create(:milestone, group: group, start_date: Date.new(2024, 2, 1), due_date: Date.new(2024, 2, 29))
                  end

                  before do
                    child_issue = create(:issue, milestone: milestone, project: create(:project, group: group))
                    create(:epic_issue, epic: epic, issue: child_issue)
                  end

                  context 'when updating only due date' do
                    let(:opts) { { due_date: 2.days.from_now.to_date } }

                    subject(:update_epic_due_date) { update_epic(opts) }

                    it 'syncs due date' do
                      expected_date = opts[:due_date].to_date
                      update_epic_due_date

                      expect(work_item.due_date).to eq(epic.end_date)
                      expect(work_item.due_date).to eq(expected_date)
                    end
                  end

                  subject(:update_epic_with_rollup_dates) { update_epic(opts) }

                  it 'sets rolledup dated for the work item', :aggregate_failures do
                    update_epic_with_rollup_dates

                    epic.reload
                    work_item = epic.work_item

                    expect(epic.start_date_sourcing_milestone_id).to eq(milestone.id)
                    expect(epic.due_date_sourcing_milestone_id).to eq(milestone.id)
                    expect(epic.start_date).to eq(milestone.start_date)
                    expect(epic.start_date_is_fixed).to be(false)
                    expect(epic.due_date).to eq(milestone.due_date)
                    expect(epic.due_date_is_fixed).to be(false)

                    expect(work_item.dates_source.start_date_is_fixed).to eq(epic.start_date_is_fixed)
                    expect(work_item.dates_source.start_date_fixed).to eq(epic.start_date_fixed)
                    expect(work_item.dates_source.start_date).to eq(epic.start_date)
                    expect(work_item.dates_source.due_date).to eq(epic.due_date)
                    expect(work_item.dates_source.start_date_sourcing_milestone_id)
                      .to eq(epic.start_date_sourcing_milestone_id)
                    expect(work_item.dates_source.due_date_sourcing_milestone_id)
                      .to eq(epic.due_date_sourcing_milestone_id)
                  end
                end

                context 'with child epic date roll up' do
                  let_it_be(:child_epic, freeze: false) do
                    create(
                      :epic, :with_synced_work_item,
                      group: group,
                      parent: epic,
                      start_date: Date.new(2024, 3, 1),
                      end_date: Date.new(2024, 3, 31)
                    )
                  end

                  before do
                    child_epic.work_item.update!(start_date: child_epic.start_date, due_date: child_epic.end_date)
                  end

                  subject(:update_epic_with_child_rollup) { update_epic(opts) }

                  it 'sets rolledup dated for the work item', :aggregate_failures do
                    update_epic_with_child_rollup

                    epic.reload
                    work_item = epic.work_item

                    expect(epic.start_date_sourcing_epic_id).to eq(child_epic.id)
                    expect(epic.due_date_sourcing_epic_id).to eq(child_epic.id)
                    expect(epic.start_date).to eq(child_epic.start_date)
                    expect(epic.start_date_is_fixed).to be(false)
                    expect(epic.due_date).to eq(child_epic.end_date)
                    expect(epic.due_date_is_fixed).to be(false)

                    expect(work_item.dates_source.start_date_is_fixed).to eq(epic.start_date_is_fixed)
                    expect(work_item.dates_source.start_date_fixed).to eq(epic.start_date_fixed)
                    expect(work_item.dates_source.start_date).to eq(epic.start_date)
                    expect(work_item.dates_source.due_date).to eq(epic.due_date)
                    expect(work_item.dates_source.start_date_sourcing_work_item_id).to eq(child_epic.issue_id)
                    expect(work_item.dates_source.due_date_sourcing_work_item_id).to eq(child_epic.issue_id)
                  end
                end
              end

              context 'with epic color' do
                let_it_be_with_reload(:epic) { create(:epic, group: group, color: '#ffffff') }

                let(:opts) { { color: ::Epic::DEFAULT_COLOR } }

                before do
                  create(:color, work_item: epic.work_item, color: epic.color)
                end

                it_behaves_like 'syncs all data from an epic to a work item', notes_on_work_item: true
              end

              context 'when updating description tasks' do
                context 'when marking a task as done' do
                  let_it_be(:description) { '- [ ] Task' }
                  let_it_be_with_reload(:epic) do
                    create(:epic, :with_synced_work_item, group: group, description: description)
                  end

                  let(:opts) do
                    {
                      description: '- [x] Task',
                      update_task: {
                        checked: true,
                        line_source: '- [ ] Task',
                        line_sourcepos: '1:4-1:4'
                      }
                    }
                  end

                  subject(:mark_task_as_done) { update_epic(opts) }

                  it_behaves_like 'syncs all data from an epic to a work item', notes_on_work_item: true

                  it 'updates the task on the epic and the work item' do
                    mark_task_as_done

                    expect(epic.reload.description).to eq('- [x] Task')
                    expect(work_item.reload.description).to eq('- [x] Task')
                  end
                end

                context 'when unchecking a task' do
                  let_it_be(:description) { '- [x] Task' }
                  let_it_be_with_reload(:epic) do
                    create(:epic, :with_synced_work_item, group: group, description: description)
                  end

                  let(:opts) do
                    {
                      description: '- [ ] Task',
                      update_task: {
                        checked: false,
                        line_source: '- [x] Task',
                        line_sourcepos: '1:4-1:4'
                      }
                    }
                  end

                  subject(:uncheck_task) { update_epic(opts) }

                  it_behaves_like 'syncs all data from an epic to a work item', notes_on_work_item: true

                  it 'updates the task on the epic and the work item' do
                    uncheck_task

                    expect(epic.reload.description).to eq('- [ ] Task')
                    expect(work_item.reload.description).to eq('- [ ] Task')
                  end
                end

                context 'when params are different than the epic attributes', :aggregate_failures do
                  before do
                    epic.work_item.create_dates_source!(start_date: 3.days.ago, due_date: 3.days.from_now)
                    epic.work_item.create_color!(color: "#123123")
                    epic.update!(title: "Outdated title", color: "#aabbcc", due_date_fixed: 3.days.ago)
                  end

                  let(:opts) do
                    {
                      description: 'New description'
                    }
                  end

                  subject(:update_description_only) { update_epic(opts) }

                  it 'only applies the changed params and updated_at' do
                    update_description_only

                    expect(epic.reload.description).to eq('New description')
                    expect(work_item.reload.description).to eq('New description')
                    expect(work_item.updated_by).to eq(epic.updated_by)
                    expect(work_item.updated_at).to eq(epic.updated_at)
                    expect(work_item.title).not_to eq('Outdated title')
                    expect(work_item.color.color).not_to eq(epic.color)
                    expect(work_item.dates_source.due_date_fixed).not_to eq(epic.due_date_fixed)
                  end
                end
              end

              context 'when updating labels' do
                let_it_be(:label1, freeze: false) { create(:group_label, group: group) }
                let_it_be(:label2, freeze: false) { create(:group_label, group: group) }
                let_it_be(:new_labels, freeze: false) { create_list(:group_label, 2, group: group) }

                before do
                  epic.labels << label1
                  epic.work_item.labels << label2
                end

                context 'and replacing labels with `label_ids` param' do
                  let(:opts) { { label_ids: new_labels.map(&:id) } }
                  let(:expected_labels) { new_labels }

                  it_behaves_like 'syncs labels between epics and epic work items'
                end

                context 'and removing label assigned to epic' do
                  let(:opts) { { add_label_ids: new_labels.map(&:id), remove_label_ids: [label1.id] } }
                  let(:expected_labels) { [new_labels, label2].flatten }

                  it_behaves_like 'syncs labels between epics and epic work items'
                end

                context 'and removing label assigned to epic work item' do
                  let(:opts) do
                    { add_label_ids: new_labels.map(&:id), remove_label_ids: [label2.id] }
                  end

                  let(:expected_labels) { [new_labels, label1].flatten }

                  it_behaves_like 'syncs labels between epics and epic work items'
                end
              end
            end

            context 'when changes are invalid', :aggregate_failures do
              it 'does not propagate the title change to the work item' do
                expect { update_epic({ title: '' }) }.to not_change { work_item.reload }

                expect(work_item.reload).to be_valid
              end
            end
          end
        end
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
