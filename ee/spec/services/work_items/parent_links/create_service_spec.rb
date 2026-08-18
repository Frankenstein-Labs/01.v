# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::ParentLinks::CreateService, feature_category: :portfolio_management do
  include LegacyEpicsHelper
  describe '#execute' do
    let_it_be(:user, freeze: false) { create(:user) }
    let_it_be(:group, freeze: false) { create(:group, reporters: user) }
    let_it_be(:project, freeze: false) { create(:project, group: group) }
    let_it_be(:work_item1, freeze: false) { create(:work_item, :epic, namespace: group) }
    let_it_be(:work_item2, freeze: false) { create(:work_item, :epic, namespace: group) }
    let_it_be(:work_item_issue, freeze: false) { create(:work_item, :issue, project: project) }
    let_it_be(:parent_epic, freeze: false) { create(:epic, :with_synced_work_item, group: group) }
    let_it_be(:other_parent_epic, freeze: false) { create(:epic, :with_synced_work_item, group: group) }
    let_it_be(:other_child_epic, freeze: false) do
      create(:epic, :with_synced_work_item, parent: other_parent_epic, group: group)
    end

    let(:link_service_class) { nil }
    let(:params) { { issuable_references: [child_work_item], synced_work_item: synced_work_item_param } }
    let(:legacy_model) { nil }

    subject(:create_link) { described_class.new(parent_work_item, user, params).execute }

    before do
      stub_licensed_features(epics: true, subepics: true)
    end

    shared_examples 'does not create parent link' do
      it 'no relationship is created' do
        expect { create_link }.not_to change { WorkItems::ParentLink.count }
      end

      it 'returns error' do
        is_expected.to eq({
          http_status: 404,
          status: :error,
          message: 'No matching work item found. Make sure that you are adding a valid work item ID.'
        })
      end
    end

    shared_examples 'creates parent link only' do |system_notes_count: 2|
      it 'creates parent links' do
        expect { create_link }.to change { WorkItems::ParentLink.count }.by(1)
                              .and change { Note.count }.by(system_notes_count)
                              .and not_change { EpicIssue.count }
      end
    end

    shared_examples 'creates parent link and deletes legacy link' do
      it 'creates parent link and removes previous legacy parent epic' do
        previous_parent = child_work_item.reload.work_item_parent

        expect { create_link }.to change { child_work_item.reload.work_item_parent }.to(parent_work_item)
          .and change { legacy_child.reload.try(relationship) }.to(nil)
          .and change { Note.count }.by(3)

        full_reference = child_work_item.namespace != parent_work_item.namespace
        child_type = child_work_item.issue_type.humanize(capitalize: false)

        expect(previous_parent.notes.last.note).to eq(
          "moved child #{child_type} #{child_work_item.to_reference} to #{parent_work_item.to_reference}"
        )

        expect(parent_work_item.notes.first.note).to eq(
          "added #{child_work_item.to_reference(full: full_reference)} as child item"
        )
        expect(child_work_item.notes.first.note)
          .to eq("added #{parent_work_item.to_reference(full: full_reference)} as parent item")
      end
    end

    shared_examples 'link creation with failures' do
      context 'when creating legacy epic link fails' do
        before do
          errors = ActiveModel::Errors.new(legacy_child).tap { |e| e.add(:base, 'Some error') }

          if legacy_model
            allow_next_instance_of(legacy_model) do |instance|
              allow(instance).to receive_messages(save: false, errors: errors)
            end
          end

          allow(legacy_child).to receive_messages(save: false, errors: errors)
        end

        it 'does not create a work item parent link or set the parent epic' do
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: 'Not able to create work item parent link',
              error_message: 'Some error',
              group_id: group.id,
              work_item_parent_id: parent_work_item.id,
              work_item_id: child_work_item.id
            })

          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(WorkItems::SyncAsEpic::SyncAsEpicError),
            { work_item_parent_id: parent_work_item.id }
          )

          expect { create_link }.to not_change { WorkItems::ParentLink.count }
                                .and not_change { legacy_child.reload.try(relationship) }

          expect(create_link)
            .to eq({ status: :error, message: "Couldn't create link due to an internal error.", http_status: 422 })
        end
      end

      context 'when creating parent link fails' do
        before do
          allow_next_instance_of(::WorkItems::ParentLink) do |instance|
            errors = ActiveModel::Errors.new(instance).tap { |e| e.add(:work_item, 'error message') }
            allow(instance).to receive_messages(save: false, errors: errors)
          end
        end

        it 'does not create a parent work item link or set parent epic' do
          error_message = "#{child_work_item.to_reference} cannot be added: error message"

          expect { create_link }.to not_change { WorkItems::ParentLink.count }
                                .and not_change { legacy_child.reload.try(relationship) }

          expect(create_link).to eq(message: error_message, status: :error, http_status: 422)
        end
      end
    end

    context 'when epic work item type' do
      context 'when subepics are not available' do
        let(:synced_work_item_param) { false }
        let(:parent_work_item) { work_item1 }
        let(:child_work_item) { work_item2 }

        before do
          stub_licensed_features(epics: true, subepics: false)
        end

        it_behaves_like 'does not create parent link'
      end
    end

    context "when parent and child work items don't have a synced epic" do
      let(:parent_work_item) { work_item1 }
      let(:child_work_item) { work_item2 }
      let(:synced_work_item_param) { true }

      it_behaves_like 'creates parent link only', system_notes_count: 0
    end

    context 'when only parent work item has a synced epic' do
      let_it_be(:parent_work_item, freeze: false) { parent_epic.work_item }
      let(:child_work_item) { work_item2 }

      context 'when synced_work_item param is true' do
        let(:synced_work_item_param) { true }

        it_behaves_like 'creates parent link only', system_notes_count: 0
      end

      context 'when synced_work_item param is false' do
        let(:synced_work_item_param) { false }

        let_it_be(:other_epic_work_item, freeze: false) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
        let_it_be(:other_epic_work_item_link, freeze: false) do
          create(:parent_link, work_item: other_epic_work_item, work_item_parent: parent_work_item,
            relative_position: 500)
        end

        before_all do
          assign_epic_parent(other_epic_work_item.synced_epic, parent_epic)
        end

        context 'when child is type :epic' do
          it_behaves_like 'creates parent link only'
        end

        context 'when child is type :issue' do
          let(:child_work_item) { work_item_issue }
          let(:child_issue) { Issue.find(child_work_item.id) }

          let_it_be(:other_issue_work_item, freeze: false) { create(:work_item, :issue, namespace: group) }
          let_it_be(:other_issue_work_item_link, freeze: false) do
            create(:parent_link, :with_epic_issue, work_item: other_issue_work_item, work_item_parent: parent_work_item,
              relative_position: 600)
          end

          it 'calls this service once' do
            allow(described_class).to receive(:new).and_call_original
            expect(described_class).to receive(:new).once

            create_link
          end

          it 'syncs parent epic and creates notes only for the work items', :aggregate_failures do
            expect { create_link }.to change { child_issue.reload.epic }.to(parent_epic)
              .and change { WorkItems::ParentLink.count }.by(1)
              .and change { Note.count }.by(2)
              .and not_change { parent_epic.reload.own_notes.count }

            expect(child_issue.epic_issue.relative_position).to eq(child_work_item.parent_link.relative_position)
            expect(child_issue.epic_issue.work_item_parent_link_id).to eq(child_work_item.parent_link.id)
            expect(child_issue.epic_issue.work_item_parent_link.work_item_id).to eq(child_issue.id)
            expect(child_issue.epic_issue.work_item_parent_link.work_item_parent.synced_epic).to eq(child_issue.epic)

            expect(parent_work_item.reload.notes.last.note)
              .to eq("added #{child_work_item.to_reference(full: true)} as child item")
            expect(child_work_item.reload.notes.last.note)
              .to eq("added #{parent_work_item.to_reference(full: true)} as parent item")
          end

          it_behaves_like 'link creation with failures' do
            let(:legacy_model) { EpicIssue }
            let(:legacy_child) { child_issue }
            let(:relationship) { :epic }
          end
        end
      end
    end

    context 'when only child work item has a synced epic' do
      let(:parent_work_item) { work_item1 }
      let(:child_work_item) { parent_epic.work_item }

      context 'when synced_work_item param is true' do
        let(:synced_work_item_param) { true }

        it_behaves_like 'creates parent link only', system_notes_count: 0
      end

      context 'when synced_work_item param is false' do
        let(:synced_work_item_param) { false }

        it_behaves_like 'creates parent link only'

        context 'when legacy epic already has a parent epic' do
          let(:child_work_item) { other_child_epic.work_item }

          it_behaves_like 'creates parent link and deletes legacy link' do
            let(:legacy_child) { other_child_epic }
            let(:relationship) { :parent }
            let(:link_service_class) { ::Epics::EpicLinks }
          end
        end
      end
    end

    context 'when both work items have a synced epic' do
      let_it_be(:child_epic, freeze: false) { create(:epic, :with_synced_work_item, group: group) }
      let_it_be(:parent_work_item, freeze: false) { parent_epic.work_item }
      let_it_be(:parent_epic, freeze: false) { parent_work_item.synced_epic }
      let(:child_work_item) { child_epic.work_item }

      context 'when synced_work_item param is true' do
        let(:synced_work_item_param) { true }

        it_behaves_like 'creates parent link only', system_notes_count: 0
      end

      context 'when synced_work_item param is false' do
        let(:synced_work_item_param) { false }

        let_it_be(:other_epic_work_item, freeze: false) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
        let_it_be(:other_epic_work_item_link, freeze: false) do
          create(:parent_link, work_item: other_epic_work_item, work_item_parent: parent_work_item,
            relative_position: 500)
        end

        before_all do
          assign_epic_parent(other_epic_work_item.synced_epic, parent_epic)
        end

        context 'when child is type :epic' do
          it 'calls this service once' do
            allow(described_class).to receive(:new).and_call_original
            expect(described_class).to receive(:new).once

            create_link
          end

          it 'syncs parent epic, sets the FK and creates notes only for the work items' do
            expect { create_link }.to change { child_epic.reload.parent }.to(parent_epic)
              .and change { WorkItems::ParentLink.count }.by(1)
              .and change { Note.count }.by(2)
              .and not_change { parent_epic.own_notes.count }
              .and not_change { child_epic.own_notes.count }

            expect(child_epic.relative_position).to eq(child_work_item.parent_link.relative_position)
            expect(child_epic.work_item_parent_link).to eq(child_work_item.parent_link)

            expect(parent_work_item.notes.last.note).to eq("added #{child_work_item.to_reference} as child item")
            expect(child_work_item.notes.last.note).to eq("added #{parent_work_item.to_reference} as parent item")
          end

          context 'when already assigned to an epic' do
            before do
              # Using -13 specifically since move_to_start would set -13 and we want not trigger any changes
              # to the record only from `relative_position` to ensure Notes still get created.
              child_epic.parent_id = other_epic_work_item.synced_epic.id
              child_epic.work_item_parent_link = create(:parent_link, work_item: child_work_item,
                work_item_parent: other_epic_work_item, relative_position: -13)
              child_epic.save!
            end

            it 'syncs the parent epic, updates the FK and creates notes' do
              previous_parent = child_work_item.reload.work_item_parent
              child_type = child_work_item.issue_type.humanize(capitalize: false)

              expect { create_link }.to change { child_epic.reload.parent }.to(parent_epic)
                .and not_change { WorkItems::ParentLink.count }
                .and change { Note.count }.by(3)
                .and not_change { parent_epic.own_notes.count }
                .and not_change { child_epic.own_notes.count }

              expect(child_epic.relative_position).to eq(child_work_item.parent_link.relative_position)
              expect(child_epic.work_item_parent_link).to eq(child_work_item.parent_link)

              expect(previous_parent.notes.last.note).to eq(
                "moved child #{child_type} #{child_work_item.to_reference} to #{parent_work_item.to_reference}"
              )
              expect(parent_work_item.notes.last.note).to eq("added #{child_work_item.to_reference} as child item")
              expect(child_work_item.notes.last.note).to eq("added #{parent_work_item.to_reference} as parent item")
            end
          end

          it_behaves_like 'link creation with failures' do
            let(:legacy_child) { child_epic }
            let(:relationship) { :parent }
          end

          context 'without group level work items license' do
            before do
              stub_licensed_features(epics: false, subepics: true)
            end

            it_behaves_like 'does not create parent link'
          end

          context 'without membership on the group' do
            let_it_be_with_reload(:group) { create(:group, :private) }
            let_it_be_with_reload(:project) { create(:project, :private, group: group) }
            let_it_be_with_reload(:user) { create(:user, guest_of: project) }
            let_it_be_with_reload(:child_work_item) { create(:work_item, :issue, namespace: group) }
            let_it_be(:parent_work_item, freeze: false) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

            it_behaves_like 'does not create parent link'
          end
        end
      end

      context 'when user is only member of a project in the group' do
        let_it_be_with_reload(:group) { create(:group, :private) }
        let_it_be_with_reload(:project) { create(:project, :private, group: group) }
        let_it_be_with_reload(:user) { create(:user, guest_of: project) }
        let_it_be_with_reload(:child_work_item) { create(:work_item, :issue, project: project) }
        let_it_be(:parent_work_item, freeze: false) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
        let(:synced_work_item_param) { false }

        it 'sets the parent correctly and syncs it' do
          expect { create_link }.to change { WorkItems::ParentLink.count }.by(1)

          expect(child_work_item.reload.work_item_parent).to eq(parent_work_item)
          expect(parent_work_item.synced_epic.reload.issues).to match_array([Issue.find(child_work_item.id)])
          expect(create_link[:status]).to eq(:success)
        end
      end
    end
  end
end
