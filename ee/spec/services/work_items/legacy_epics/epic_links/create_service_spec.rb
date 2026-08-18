# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::EpicLinks::CreateService, feature_category: :team_planning do
  include NestedEpicsHelper
  include LegacyEpicsHelper

  describe '#execute' do
    let_it_be(:ancestor, freeze: false) { create(:group) }
    let_it_be(:group, freeze: false) { create(:group, parent: ancestor) }
    let_it_be(:user, freeze: false) { create(:user) }
    let_it_be(:other_group, freeze: false) { create(:group) }

    let(:epic) { create(:epic, group: group) }
    let(:epic_to_add) { create(:epic, group: group) }
    let(:expected_error) { 'No matching epic found. Make sure that you are adding a valid epic URL.' }
    let(:expected_code) { 404 }
    let(:valid_reference) { epic_to_add.to_reference(full: true) }
    let(:references) { [valid_reference] }
    let(:params) { { issuable_references: references } }

    subject(:add_epic) { described_class.new(epic, user, params).execute }

    shared_examples 'system notes created' do
      it 'creates system notes' do
        expect { subject }.to change { Note.system.count }.from(0).to(2)
      end
    end

    shared_examples 'returns success' do
      it 'creates a new relationship, updates epic and returns success status', :aggregate_failures do
        expect { subject }.to change { epic.children.count }.by(1)

        expect(epic.reload.children).to include(epic_to_add)
        expect(subject.keys).to match_array([:status, :created_references])
        expect(subject[:status]).to eq(:success)
        expect(subject[:created_references]).to match_array([epic_to_add])
      end

      it 'moves the new child epic to the top and moves the existing ones down' do
        existing_child_epic = create(:epic, group: group, parent: epic, relative_position: 1000)

        subject

        expect(epic_to_add.reload.relative_position).to be < existing_child_epic.reload.relative_position
      end
    end

    shared_examples 'returns an error' do
      it 'returns an error and no relationship is created' do
        expect { subject }.not_to change { epic.children.count }

        expect(subject).to eq(message: expected_error, status: :error, http_status: expected_code)
      end
    end

    context 'when subepics feature is disabled' do
      before do
        stub_licensed_features(epics: true, subepics: false)
      end

      include_examples 'returns an error'
    end

    context 'when subepics feature is enabled' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      context 'when an error occurs' do
        context 'when a single epic is given' do
          context 'when user does not have access for the parent' do
            include_examples 'returns an error'
          end

          context 'when a user has permissions to add an epic' do
            before_all do
              group.add_guest(user)
            end

            context 'when an epic from another group is given' do
              before do
                epic_to_add.update!(group: other_group)
                epic_to_add.work_item.update!(namespace: other_group)
              end

              context 'when user has no permission' do
                let(:params) { { target_issuable: epic_to_add } }

                before do
                  epic_to_add.update!(confidential: true)
                  epic_to_add.work_item.update!(confidential: true)
                end

                include_examples 'returns an error'
              end
            end

            context 'when hierarchy is cyclic' do
              context 'when given child epic is the same as given parent' do
                let(:references) { [epic.to_reference(full: true)] }
                let(:expected_code) { 422 }
                let(:expected_error) do
                  "#{epic.work_item.to_reference} cannot be added: is not allowed to point to itself"
                end

                include_examples 'returns an error'
              end

              context 'when given child epic is parent of the given parent' do
                let(:expected_code) { 422 }
                let(:expected_error) do
                  "#{epic_to_add.work_item.to_reference} cannot be added: it's already present in this item's hierarchy"
                end

                before do
                  assign_epic_parent(epic, epic_to_add)
                end

                include_examples 'returns an error'
              end

              context 'when new child epic is an ancestor of the given parent' do
                let(:expected_code) { 422 }
                let(:expected_error) do
                  "#{epic_to_add.work_item.to_reference} cannot be added: reached maximum depth and it's already " \
                    "present in this item's hierarchy"
                end

                before do
                  # epic_to_add -> epic1 -> epic2 -> epic
                  epic1 = create(:epic, :with_work_item_parent, group: group, parent: epic_to_add)
                  epic2 = create(:epic, :with_work_item_parent, group: group, parent: epic1)
                  assign_epic_parent(epic, epic2)
                end

                include_examples 'returns an error'
              end
            end

            context 'when adding an epic that is already a child of the parent epic' do
              let(:expected_error) { "Epic(s) already assigned" }
              let(:expected_code) { 409 }

              before do
                assign_epic_parent(epic_to_add, epic)
              end

              include_examples 'returns an error'
            end

            context 'when adding to an Epic that is already at maximum depth' do
              before do
                add_parents_to(epic: epic, count: 6)
              end

              let(:expected_code) { 422 }
              let(:expected_error) { "#{epic_to_add.work_item.to_reference} cannot be added: reached maximum depth" }

              include_examples 'returns an error'
            end
          end
        end

        context 'when multiple epics are given' do
          let_it_be(:another_epic, freeze: false) { create(:epic, group: ancestor) }

          let(:references) { [epic_to_add.to_reference(full: true), another_epic.to_reference(full: true)] }

          context 'when a user has permissions to add an epic' do
            before_all do
              group.add_developer(user)
            end

            context 'when adding epics that are already a child of the parent epic' do
              let(:expected_error) { 'Epic(s) already assigned' }
              let(:expected_code) { 409 }

              before do
                assign_epic_parent(epic_to_add, epic)
                assign_epic_parent(another_epic, epic)
              end

              include_examples 'returns an error'
            end

            context 'when total depth after adding would exceed limit' do
              let(:expected_code) { 422 }
              let(:expected_error) do
                "#{epic_to_add.work_item.to_reference} cannot be added: reached maximum depth"
              end

              before do
                add_parents_to(epic: epic, count: 1) # epic is on level 2

                # epic_to_add has 5 children (level 6 including epic_to_add)
                # that would mean level 8 after relating epic_to_add on epic
                add_children_to(epic: epic_to_add, count: 5)
              end

              include_examples 'returns an error'
            end

            context 'when an epic from a another group is given' do
              before do
                epic_to_add.update!(group: other_group)
                epic_to_add.work_item.update!(namespace: other_group)
                other_group.update!(visibility: Gitlab::VisibilityLevel::PRIVATE)
              end

              context 'when user has insufficient permissions' do
                include_examples 'returns an error'
              end
            end

            context 'when hierarchy is cyclic' do
              context 'when given child epic is the same as given parent' do
                let(:references) { [epic.to_reference(full: true), another_epic.to_reference(full: true)] }
                let(:expected_code) { 422 }
                let(:expected_error) do
                  "#{epic.work_item.to_reference} cannot be added: is not allowed to point to itself"
                end

                include_examples 'returns an error'
              end

              context 'when given child epic is parent of the given parent' do
                let(:expected_code) { 422 }
                let(:expected_error) do
                  "#{epic_to_add.work_item.to_reference} cannot be added: it's already present in this item's hierarchy"
                end

                before do
                  assign_epic_parent(epic, epic_to_add)
                end

                include_examples 'returns an error'
              end
            end

            context 'when the reference list is empty' do
              let(:references) { [] }

              include_examples 'returns an error'
            end

            context 'when there are invalid references' do
              let_it_be_with_refind(:epic) { create(:epic, confidential: true, group: group) }
              let_it_be(:invalid_epic1, freeze: false) { create(:epic, group: group) }
              let_it_be(:valid_epic, freeze: false) { create(:epic, :confidential, group: group) }
              let_it_be(:invalid_epic2, freeze: false) { create(:epic, group: group) }

              let(:references) do
                [
                  invalid_epic1.to_reference(full: true), valid_epic.to_reference(full: true),
                  invalid_epic2.to_reference(full: true)
                ]
              end

              it 'does not add any reference' do
                expect { add_epic }.to not_change { WorkItems::ParentLink.count }

                expect(epic.reload.children).to be_empty
              end

              it 'returns error status' do
                expect(add_epic[:status]).to eq(:error)
                expect(add_epic[:http_status]).to eq(422)
                expect(add_epic[:message]).to include(
                  "#{invalid_epic1.work_item.to_reference} cannot be added: cannot assign a " \
                    "non-confidential epic to a confidential parent. Make the epic confidential and try again.")
                  .and include(
                    "#{invalid_epic2.work_item.to_reference} cannot be added: cannot assign a non-confidential " \
                      "epic to a confidential parent. Make the epic confidential and try again."
                  )
              end
            end
          end
        end
      end

      context 'when everything is ok' do
        let_it_be_with_reload(:another_epic) { create(:epic, group: group) }

        before_all do
          group.add_guest(user)
        end

        context 'when a correct reference is given' do
          include_examples 'returns success'
          include_examples 'system notes created'

          context 'when parent has inherited dates' do
            let_it_be_with_reload(:other_parent) do
              create(
                :epic, group: group, start_date: 1.day.ago, due_date: 1.day.from_now,
                start_date_is_fixed: false, due_date_is_fixed: false
              )
            end

            let_it_be_with_reload(:epic_to_add) do
              create(:epic, :with_work_item_parent, group: group, start_date: 1.day.ago, due_date: 1.day.from_now,
                parent: other_parent)
            end

            before do
              epic.update!(start_date: nil, due_date: nil, start_date_is_fixed: false, due_date_is_fixed: false)
              epic.work_item.create_dates_source(start_date: nil, due_date: nil, start_date_is_fixed: false,
                due_date_is_fixed: false)

              other_parent.work_item.create_dates_source(start_date: other_parent.start_date,
                due_date: other_parent.due_date)

              epic_to_add.work_item.create_dates_source(start_date: epic_to_add.start_date,
                due_date: epic_to_add.due_date)
            end

            it 'correctly updates the parent dates', :sidekiq_inline do
              expect { add_epic }.to change { epic.reload.children.count }.by(1)
                                .and change { epic.reload.start_date }.from(nil).to(epic_to_add.start_date)
                                .and change { epic.due_date }.from(nil).to(epic_to_add.due_date)
                                .and change { epic.start_date_sourcing_epic_id }.from(nil).to(epic_to_add.id)
                                .and change { epic.due_date_sourcing_epic_id }.from(nil).to(epic_to_add.id)
                                .and change { other_parent.reload.children.count }.by(-1)
                                .and change { other_parent.start_date }.from(epic_to_add.start_date).to(nil)
                                .and change { other_parent.due_date }.from(epic_to_add.due_date).to(nil)

              epic_dates_source = epic.work_item.dates_source
              other_parent_dates_source = other_parent.work_item.dates_source

              expect(epic_dates_source.start_date).to eq(epic_to_add.start_date)
              expect(epic_dates_source.due_date).to eq(epic_to_add.due_date)
              expect(epic_dates_source.start_date_sourcing_work_item_id).to eq(epic_to_add.work_item.id)
              expect(epic_dates_source.due_date_sourcing_work_item_id).to eq(epic_to_add.work_item.id)
              expect(other_parent_dates_source.start_date).to be_nil
              expect(other_parent_dates_source.due_date).to be_nil
            end
          end
        end

        context 'when an epic from a subgroup is given' do
          let_it_be(:subgroup, freeze: false) { create(:group, parent: group) }

          before do
            epic_to_add.update!(group: subgroup)
          end

          include_examples 'returns success'
          include_examples 'system notes created'
        end

        context 'when an epic from another group is given' do
          before_all do
            other_group.add_reporter(user)
          end

          before do
            epic_to_add.update!(group: other_group)
          end

          include_examples 'returns success'
          include_examples 'system notes created'
        end

        context 'when an epic from ancestor group is given' do
          before_all do
            ancestor.add_guest(user)
          end

          before do
            epic_to_add.update!(group: ancestor)
          end

          include_examples 'returns success'
          include_examples 'system notes created'
        end

        context 'when multiple valid epics are given' do
          let(:references) do
            [epic_to_add.to_reference(full: true), another_epic.to_reference(full: true)]
          end

          it 'creates new relationships' do
            expect { add_epic }.to change { epic.children.count }.by(2)

            expect(epic.reload.children).to match_array([epic_to_add, another_epic])
          end

          it 'creates system notes' do
            expect { add_epic }.to change { Note.system.count }.from(0).to(4)
          end

          it 'returns success status and created links', :aggregate_failures do
            expect(add_epic.keys).to match_array([:status, :created_references])
            expect(add_epic[:status]).to eq(:success)
            expect(add_epic[:created_references]).to match_array([epic_to_add, another_epic])
          end

          it 'avoids un-necessary database queries' do
            control = ActiveRecord::QueryRecorder.new { add_epic }

            new_epics = Array.new(2) { create(:epic, group: group) }

            # threshold is 8 because
            # 1. we need to check hierarchy for each child epic (3 queries)
            # 2. we have to update the  record (2 including releasing savepoint)
            # 3. we have to update start and due dates for all updated epics
            # 4. we temporarily increased this from 6 due to
            #    https://gitlab.com/gitlab-org/gitlab/issues/11539
            expect do
              ActiveRecord::QueryRecorder.new do
                described_class.new(epic, user,
                  { issuable_references: new_epics.map { |epic| epic.to_reference(full: true) } }
                ).execute
              end
            end.not_to exceed_query_limit(control).with_threshold(8)
          end

          context 'when parent has inherited dates' do
            let_it_be_with_reload(:epic_to_add) do
              create(:epic, group: group, start_date: 5.days.ago, due_date: 3.days.from_now)
            end

            let_it_be_with_reload(:another_epic) do
              create(:epic, group: group, start_date: 3.days.ago, due_date: 5.days.from_now)
            end

            before do
              epic.update!(start_date: nil, due_date: nil, start_date_is_fixed: false, due_date_is_fixed: false)
              epic.work_item.create_dates_source(start_date: nil, due_date: nil, start_date_is_fixed: false,
                due_date_is_fixed: false)

              epic_to_add.work_item.create_dates_source(start_date: epic_to_add.start_date,
                due_date: epic_to_add.due_date)

              another_epic.work_item.create_dates_source(start_date: another_epic.start_date,
                due_date: another_epic.due_date)
            end

            it 'correctly updates the parent dates', :sidekiq_inline, :aggregate_failures do
              expect { add_epic }.to change { epic.reload.children.count }.by(2)
                .and change { epic.start_date }.from(nil).to(epic_to_add.start_date)
                .and change { epic.due_date }.from(nil).to(another_epic.due_date)
                .and change { epic.start_date_sourcing_epic_id }.from(nil).to(epic_to_add.id)
                .and change { epic.due_date_sourcing_epic_id }.from(nil).to(another_epic.id)

              epic_dates_source = epic.work_item.dates_source

              expect(epic_dates_source.start_date).to eq(epic_to_add.start_date)
              expect(epic_dates_source.due_date).to eq(another_epic.due_date)
              expect(epic_dates_source.start_date_sourcing_work_item_id).to eq(epic_to_add.work_item.id)
              expect(epic_dates_source.due_date_sourcing_work_item_id).to eq(another_epic.work_item.id)
            end
          end
        end

        context 'when at least one epic is still not assigned to the parent epic' do
          before do
            assign_epic_parent(epic_to_add, epic)
          end

          let(:references) do
            [epic_to_add.to_reference(full: true), another_epic.to_reference(full: true)]
          end

          it 'creates new relationships' do
            expect { add_epic }.to change { epic.children.count }.from(1).to(2)

            expect(epic.reload.children).to match_array([epic_to_add, another_epic])
          end

          it 'creates system notes' do
            expect { add_epic }.to change { Note.system.count }.from(0).to(2)
          end

          it 'returns success status and created links', :aggregate_failures do
            expect(add_epic.keys).to match_array([:status, :created_references])
            expect(add_epic[:status]).to eq(:success)
            expect(add_epic[:created_references]).to match_array([another_epic])
          end
        end

        context 'when adding an Epic that has existing children' do
          context 'when Epic to add has more than 5 children' do
            before do
              create_list(:epic, 6, group: group, parent: epic_to_add)
            end

            include_examples 'returns success'
            include_examples 'system notes created'
          end
        end

        context 'when an epic is already assigned to another epic' do
          before do
            assign_epic_parent(epic_to_add, another_epic)
          end

          it 'creates system notes' do
            # 3 because now we add system note to old parent indicating child has been 'moved'
            expect { add_epic }.to change { Note.system.count }.from(0).to(3)
          end

          include_examples 'returns success'
        end
      end

      context 'when child and parent epics have a synced work item' do
        let_it_be(:parent_work_item, freeze: false) { create(:work_item, :epic, namespace: group) }
        let_it_be(:child_work_item, freeze: false) { create(:work_item, :epic, namespace: group) }
        let_it_be(:parent_epic, freeze: false) { create(:epic, group: group, issue_id: parent_work_item.id) }
        let_it_be(:child_epic, freeze: false) do
          create(:epic, group: group, issue_id: child_work_item.id, title: 'The child epic')
        end

        let(:synced_epic_param) { false }
        let(:epic) { parent_epic }
        let(:params) { { issuable_references: [child_epic.to_reference], synced_epic: synced_epic_param } }

        before_all do
          group.add_reporter(user)
        end

        it 'creates a new relationship for the epic and the synced work item' do
          expect { add_epic }.to change { parent_epic.children.count }.by(1)
            .and(change { WorkItems::ParentLink.count }.by(1))

          expect(parent_epic.reload.children).to include(child_epic)
          expect(parent_work_item.reload.work_item_children).to include(child_work_item)
          expect(child_epic.reload.relative_position).to eq(child_work_item.parent_link.reload.relative_position)
        end

        it 'creates system note for epics' do
          expect { add_epic }.to change { Note.system.count }.by(2)

          expect(parent_epic.notes.last.note).to eq("added #{child_epic.work_item.to_reference} as child item")
          expect(child_epic.notes.last.note).to eq("added #{parent_epic.work_item.to_reference} as parent item")
        end

        context 'with multiple children' do
          let_it_be(:child_work_item2, freeze: false) { create(:work_item, :epic, namespace: group) }
          let_it_be(:child_epic2, freeze: false) { create(:epic, group: group, issue_id: child_work_item2.id) }

          let(:params) { { issuable_references: [child_epic.to_reference, child_epic2.to_reference] } }

          it 'creates a new relationship for the epics and their synced work items' do
            expect { add_epic }.to change { parent_epic.children.count }.by(2)
              .and(change { WorkItems::ParentLink.count }.by(2))

            expect(parent_epic.reload.children).to include(child_epic, child_epic2)
            expect(parent_work_item.reload.work_item_children).to include(child_work_item, child_work_item2)
            expect(child_epic.reload.relative_position).to eq(child_work_item.reload.parent_link.relative_position)
            expect(child_epic2.reload.relative_position).to eq(child_work_item2.reload.parent_link.relative_position)
          end

          it 'creates system notes only for the epics' do
            child_note_text = "added #{parent_epic.work_item.to_reference} as parent item"
            expect { add_epic }.to change { Note.system.count }.by(4)

            expect(child_epic.notes.last.note).to eq(child_note_text)
            expect(child_epic2.notes.last.note).to eq(child_note_text)
            expect(parent_epic.notes.last(2).pluck(:note)).to contain_exactly(
              "added #{child_epic.work_item.to_reference} as child item",
              "added #{child_epic2.work_item.to_reference} as child item"
            )
          end
        end
      end
    end
  end
end
