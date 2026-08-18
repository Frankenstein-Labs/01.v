# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::ParentLinks::ReorderService, feature_category: :portfolio_management do
  include LegacyEpicsHelper
  describe '#execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user, developer_of: group) }

    let_it_be_with_reload(:parent) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let_it_be_with_reload(:top_adjacent) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let_it_be_with_reload(:last_adjacent) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let_it_be_with_reload(:work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

    let(:relative_position) { 'AFTER' }
    let(:adjacent_work_item) { top_adjacent }
    let(:base_params) { { target_issuable: work_item, relative_position: relative_position } }
    let(:params) { base_params.merge(adjacent_work_item: adjacent_work_item) }

    let(:work_item_position) { work_item.parent_link.reload.relative_position }
    let(:top_adjacent_position) { top_adjacent.parent_link.reload.relative_position }
    let(:last_adjacent_position) { last_adjacent.parent_link.reload.relative_position }
    let(:synced_moving_object) { work_item.synced_epic.reload }

    subject(:execute) { described_class.new(parent, user, params).execute }

    shared_examples 'reorders the hierarchy' do
      context 'when relative_position is AFTER' do
        let(:relative_position) { 'AFTER' }

        it 'reorders correctly' do
          subject

          expect(work_item_position).to be > top_adjacent_position
          expect(work_item_position).to be < last_adjacent_position

          if synced_moving_object
            expect(synced_moving_object.relative_position).to be > top_adjacent_position
            expect(synced_moving_object.relative_position).to be < last_adjacent_position
          end
        end
      end

      context 'when relative_position is BEFORE' do
        let(:relative_position) { 'BEFORE' }

        it 'reorders correctly' do
          subject

          expect(work_item_position).to be < top_adjacent_position
          expect(work_item_position).to be < last_adjacent_position

          if synced_moving_object
            expect(synced_moving_object.relative_position).to be < top_adjacent_position
            expect(synced_moving_object.relative_position).to be < last_adjacent_position
          end
        end
      end
    end

    shared_examples 'only changes work item' do
      it 'does not change synced moving object relative position but work item one' do
        expect { subject }.to not_change { synced_moving_object.reload.relative_position }
          .and change { work_item.parent_link.reload.relative_position }
      end
    end

    shared_examples 'when saving fails' do |failing_class, expect_error_log: false, expect_error_message: false|
      it "does not change any position when saving #{failing_class}" do
        allow_next_found_instance_of(failing_class) do |instance|
          # Epic and EpicIssue are saved with !
          allow(instance).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)
          # WorkItem::ParentLink is saved without a !
          allow(instance).to receive(:save).and_return(false)
        end

        if expect_error_log
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: "Not able to sync re-ordering work item",
              error_message: 'Record invalid',
              namespace_id: group.id,
              synced_moving_object_id: synced_moving_object.id,
              synced_moving_object_class: synced_moving_object.class
            })

        end

        expect { execute }.to not_change { work_item.parent_link.reload.relative_position }
          .and not_change { synced_moving_object.reload.relative_position }

        if expect_error_message
          expect(execute)
            .to eq({ status: :error, message: "Couldn't re-order due to an internal error.", http_status: 422 })
        end
      end
    end

    shared_context 'with new parent that has children' do
      let_it_be_with_reload(:new_parent) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be_with_reload(:new_sibling1) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be_with_reload(:new_sibling2) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

      let_it_be_with_reload(:new_parent_link) do
        create(:parent_link, work_item: new_parent, work_item_parent: parent, relative_position: 30)
      end

      let_it_be_with_reload(:new_sibling1_link1) do
        create(:parent_link, work_item: new_sibling1, work_item_parent: new_parent, relative_position: 10)
      end

      let_it_be_with_reload(:new_sibling1_link2) do
        create(:parent_link, work_item: new_sibling2, work_item_parent: new_parent, relative_position: 20)
      end

      let(:params) { base_params.merge(adjacent_work_item: new_sibling2, relative_position: "BEFORE") }

      before do
        assign_epic_parent(new_parent.synced_epic, parent.synced_epic, relative_position: 50)
        assign_epic_parent(new_sibling1.synced_epic, new_parent.synced_epic, relative_position: 10)
        assign_epic_parent(new_sibling2.synced_epic, new_parent.synced_epic, relative_position: 20)
      end

      subject(:move_child) { described_class.new(new_parent, user, params).execute }
    end

    context 'when adjacent_work_item parent link is missing' do
      let(:synced_moving_object) { nil }

      before do
        stub_licensed_features(subepics: true, epics: true)
        create(:parent_link, work_item: work_item, work_item_parent: parent)
      end

      context 'when adjacent work item has a synced epic' do
        it 'creates a new parent link' do
          expect(top_adjacent.reload.parent_link).to be_nil
          expect { execute }.to change { ::WorkItems::ParentLink.count }.by(1)
          expect(top_adjacent.reload.parent_link).to be_present
        end
      end

      context 'when adjacent work item has no synced epic' do
        let_it_be_with_reload(:top_adjacent) { create(:work_item, :epic, namespace: group) }

        it 'does not create a new parent link' do
          expect { execute }.not_to change { WorkItems::ParentLink.count }
        end
      end
    end

    context 'when moving an epic work item' do
      let(:synced_moving_object) { work_item.synced_epic.reload }

      let_it_be_with_reload(:top_adjacent_link) do
        create(:parent_link, work_item: top_adjacent, work_item_parent: parent, relative_position: 20)
      end

      let_it_be_with_reload(:last_adjacent_link) do
        create(:parent_link, work_item: last_adjacent, work_item_parent: parent, relative_position: 30)
      end

      let_it_be_with_reload(:work_item_link) do
        create(:parent_link, work_item: work_item, work_item_parent: parent, relative_position: 40)
      end

      context 'when subepics feature is not available' do
        before do
          stub_licensed_features(epics: true, subepics: false)
        end

        it 'returns an error' do
          service_response = execute
          expect { service_response }.not_to change { ::WorkItems::ParentLink.count }
          expect(service_response[:message])
            .to eq('No matching work item found. Make sure that you are adding a valid work item ID.')
        end
      end

      context 'when subepics feature is available' do
        before do
          stub_licensed_features(epics: true, subepics: true)
        end

        context 'when synced epics for the work items exist' do
          before do
            assign_epic_parent(top_adjacent.synced_epic, parent.synced_epic, relative_position: 20)
            assign_epic_parent(last_adjacent.synced_epic, parent.synced_epic, relative_position: 30)
            assign_epic_parent(work_item.synced_epic, parent.synced_epic, relative_position: 40)
          end

          context 'without group level work items license' do
            before do
              stub_licensed_features(epics: false, subepics: true)
            end

            it 'does not change the relative position of the synced epic' do
              expect(execute).to eq(
                {
                  status: :error,
                  message: "No matching work item found. Make sure that you are adding a valid work item ID.",
                  http_status: 404
                }
              )
            end
          end
        end

        context 'when synced_work_item param is set' do
          let(:synced_moving_object) { nil }
          let(:params) { base_params.merge(adjacent_work_item: adjacent_work_item, synced_work_item: true) }

          it_behaves_like 'reorders the hierarchy'

          context 'when changing parent and reordering' do
            include_context 'with new parent that has children'

            context 'when work_item_parent_link FK is already set' do
              before do
                work_item.synced_epic&.update!(parent: parent.synced_epic, work_item_parent_link: work_item.parent_link)
              end

              it 'updates work item parent and legacy epic parent' do
                expect { move_child }.to change { work_item.reload.work_item_parent }.from(parent).to(new_parent)
                                    .and change { work_item.synced_epic.reload.parent }.from(parent.synced_epic)
                                                                                        .to(new_parent.synced_epic)
                                    .and change {
                                           work_item.synced_epic.reload.work_item_parent_link.work_item_parent
                                         }.to(new_parent)

                expect(new_parent.work_item_children_by_relative_position).to eq([new_sibling1, work_item,
                  new_sibling2])
              end
            end
          end

          context 'when synced_work_item param is set' do
            let(:synced_moving_object) { nil }
            let(:params) { base_params.merge(adjacent_work_item: adjacent_work_item, synced_work_item: true) }

            it_behaves_like 'reorders the hierarchy'
            it_behaves_like 'only changes work item' do
              let(:synced_moving_object) { work_item.synced_epic.reload }
            end
          end
        end

        context 'when synced epic for the moving work item do not exist' do
          let(:synced_moving_object) { nil }
          let_it_be_with_reload(:work_item) { create(:work_item, :epic, namespace: group) }

          it_behaves_like 'reorders the hierarchy'
        end

        context 'when synced epics for the parent epic do not exist' do
          let_it_be_with_reload(:parent) { create(:work_item, :epic, namespace: group) }

          it_behaves_like 'only changes work item'
        end

        it_behaves_like 'when saving fails', Epic, expect_error_log: true, expect_error_message: true
        it_behaves_like 'when saving fails', WorkItems::ParentLink
      end
    end

    context 'when moving an issue work item' do
      let(:synced_moving_object) { epic_issue.reload }

      let_it_be_with_reload(:work_item) { create(:work_item, :issue, namespace: group) }

      let_it_be_with_reload(:work_item_link) do
        create(:parent_link, work_item: work_item, work_item_parent: parent, relative_position: 40)
      end

      let_it_be(:epic_issue) do
        create(
          :epic_issue, epic: parent.synced_epic,
          issue: Issue.find(work_item.id), relative_position: 40, work_item_parent_link: work_item_link
        )
      end

      let_it_be_with_reload(:top_adjacent_link) do
        create(:parent_link, work_item: top_adjacent, work_item_parent: parent, relative_position: 20)
      end

      let_it_be_with_reload(:last_adjacent_link) do
        create(:parent_link, work_item: last_adjacent, work_item_parent: parent, relative_position: 30)
      end

      before do
        stub_licensed_features(epics: true, subepics: true)

        assign_epic_parent(top_adjacent.synced_epic, parent.synced_epic, relative_position: 20)
        assign_epic_parent(last_adjacent.synced_epic, parent.synced_epic, relative_position: 30)
      end

      it_behaves_like 'reorders the hierarchy'

      context 'when changing parent and reordering' do
        include_context 'with new parent that has children'

        it 'updates work item parent and epic_issue epic' do
          expect { move_child }
            .to change { work_item.reload.work_item_parent }.from(parent).to(new_parent)
            .and change { work_item.epic_issue.reload.epic }.from(parent.synced_epic).to(new_parent.synced_epic)

          expect(new_parent.work_item_children_by_relative_position).to eq([new_sibling1, work_item, new_sibling2])
          expect(work_item.epic_issue.work_item_parent_link).to eq(work_item.parent_link)
        end

        context 'without group level work items license' do
          before do
            stub_licensed_features(epics: false)
          end

          it 'does not change the relative position of the synced epic' do
            expect(execute).to eq(
              {
                status: :error,
                message: "No matching work item found. Make sure that you are adding a valid work item ID.",
                http_status: 404
              }
            )
          end
        end
      end

      context 'when synced EpicIssue for the moving work item do not exist' do
        let(:synced_moving_object) { nil }
        let_it_be_with_reload(:epic_issue) { nil }

        it_behaves_like 'reorders the hierarchy'
      end

      it_behaves_like 'when saving fails', EpicIssue, expect_error_log: true, expect_error_message: true
      it_behaves_like 'when saving fails', WorkItems::ParentLink
    end
  end
end
