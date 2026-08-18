# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuable::DestroyService, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }

  subject(:service) { described_class.new(container: nil, current_user: user) }

  describe '#execute' do
    context 'when destroying an epic' do
      let_it_be(:group) { create(:group) }
      let_it_be(:label1) { create(:group_label, group: group) }
      let_it_be(:label2, freeze: false) { create(:group_label, group: group) }

      let_it_be_with_refind(:epic) { create(:epic, group: group, labels: [label1]) }
      let_it_be_with_refind(:work_item) { epic.sync_object }

      context 'when deleting the epic' do
        context 'and deletes epic, epic work item and label links', :sidekiq_inline do
          let(:issuable) { epic }
          let(:sync_object) { work_item }

          before do
            sync_object.labels << label2
          end

          it 'deletes the epic and the epic work item' do
            epic_id = epic.id
            epic_work_item_id = epic.issue_id

            expect { subject.execute(issuable) }.to change { Epic.count }.by(-1).and(
              change { WorkItem.count }.by(-1)).and(change { LabelLink.count(-2) })

            expect(Epic.find_by_id(epic_id)).to be_nil
            expect(WorkItem.find_by_id(epic_work_item_id)).to be_nil
          end

          it 'records usage ping epic destroy event' do
            expect(Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(
              :track_epic_destroyed).with(author: user, namespace: group)

            subject.execute(issuable)
          end
        end

        it_behaves_like 'service deleting todos' do
          let(:issuable) { epic }
          let(:sync_object) { work_item }
        end

        it_behaves_like 'service deleting label links' do
          let(:issuable) { epic }
          let(:sync_object) { work_item }
        end
      end

      context 'when deleting the epic work item' do
        context 'and deletes epic, epic work item and label links', :sidekiq_inline do
          let(:issuable) { work_item }
          let(:sync_object) { epic }

          before do
            sync_object.labels << label2
          end

          it 'deletes the epic and the epic work item' do
            epic_id = epic.id
            epic_work_item_id = epic.issue_id

            expect { subject.execute(issuable) }.to change { Epic.count }.by(-1).and(
              change { WorkItem.count }.by(-1)).and(change { LabelLink.count(-2) })

            expect(Epic.find_by_id(epic_id)).to be_nil
            expect(WorkItem.find_by_id(epic_work_item_id)).to be_nil
          end
        end

        it_behaves_like 'service deleting todos' do
          let(:issuable) { work_item }
          let(:sync_object) { epic }
        end

        it_behaves_like 'service deleting label links' do
          let(:issuable) { work_item }
          let(:sync_object) { epic }
        end
      end

      context 'with unified notes' do
        shared_examples 'deletes notes on both epic and epic work item' do
          it 'deletes the epic, epic work item and all notes' do
            epic_id = epic.id
            epic_work_item_id = epic.issue_id

            expect(Note.where(noteable_type: 'Epic', noteable_id: epic_id).count).to eq(2)
            expect(Note.where(noteable_type: 'Issue', noteable_id: epic_work_item_id).count).to eq(1)

            expect { subject.execute(issuable) }.to change { Epic.count }.by(-1).and(
              change { WorkItem.count }.by(-1)).and(change { Note.count }.by(-3))

            expect(Epic.find_by_id(epic_id)).to be_nil
            expect(WorkItem.find_by_id(epic_work_item_id)).to be_nil
            expect(Note.where(noteable_type: 'Epic', noteable_id: epic_id).count).to eq(0)
            expect(Note.where(noteable_type: 'Issue', noteable_id: epic_work_item_id).count).to eq(0)
          end
        end

        context 'when deleting the epic' do
          let_it_be(:epic, freeze: false) { create(:epic, group: group) }
          let_it_be(:work_item) { epic.sync_object }
          let_it_be(:note1, freeze: false) { create(:note, noteable: epic, note: 'first note on epic') }
          let_it_be(:note2) { create(:note, noteable: epic, note: 'second note on epic') }
          let_it_be(:note3) { create(:note, noteable: work_item, note: 'first note on epic work item') }

          let_it_be(:issuable) { epic }
          let_it_be(:sync_object) { work_item }

          it_behaves_like 'deletes notes on both epic and epic work item'
        end

        context 'when deleting the epic work item' do
          let_it_be(:epic, freeze: false) { create(:epic, group: group) }
          let_it_be(:work_item) { epic.sync_object }
          let_it_be(:note1, freeze: false) { create(:note, noteable: epic, note: 'first note on epic') }
          let_it_be(:note2) { create(:note, noteable: epic, note: 'second note on epic') }
          let_it_be(:note3) { create(:note, noteable: work_item, note: 'first note on epic work item') }

          let_it_be(:issuable) { work_item }
          let_it_be(:sync_object) { epic }

          it_behaves_like 'deletes notes on both epic and epic work item'
        end
      end

      context 'with unified resource_label_events' do
        shared_examples 'deletes label events on both epic and epic work item' do
          it 'deletes the epic, epic work item and all notes' do
            epic_id = epic.id
            epic_work_item_id = epic.issue_id

            expect(ResourceLabelEvent.where(epic_id: epic_id).count).to eq(1)
            expect(ResourceLabelEvent.where(issue_id: epic_work_item_id).count).to eq(1)

            expect { subject.execute(issuable) }.to change { Epic.count }.by(-1).and(
              change { WorkItem.count }.by(-1)).and(change { ResourceLabelEvent.count }.by(-2))

            expect(Epic.find_by_id(epic_id)).to be_nil
            expect(WorkItem.find_by_id(epic_work_item_id)).to be_nil
            expect(ResourceLabelEvent.where(epic_id: epic_id).count).to eq(0)
            expect(ResourceLabelEvent.where(issue_id: epic_work_item_id).count).to eq(0)
          end
        end

        context 'when deleting the epic' do
          let_it_be(:epic, freeze: false) { create(:epic, group: group) }
          let_it_be(:work_item) { epic.sync_object }
          let_it_be(:label1) { create(:group_label, group: group) }
          let_it_be(:label2, freeze: false) { create(:group_label, group: group) }
          let_it_be(:label_resource_event1) { create(:resource_label_event, epic: epic, label: label1) }
          let_it_be(:label_resource_event2) { create(:resource_label_event, issue: work_item, label: label2) }

          let_it_be(:issuable) { epic }
          let_it_be(:sync_object) { work_item }

          it_behaves_like 'deletes label events on both epic and epic work item'
        end

        context 'when deleting the epic work item' do
          let_it_be(:epic, freeze: false) { create(:epic, group: group) }
          let_it_be(:work_item) { epic.sync_object }
          let_it_be(:label1) { create(:group_label, group: group) }
          let_it_be(:label2, freeze: false) { create(:group_label, group: group) }
          let_it_be(:label_resource_event1) { create(:resource_label_event, epic: epic, label: label1) }
          let_it_be(:label_resource_event2) { create(:resource_label_event, issue: work_item, label: label2) }

          let_it_be(:issuable) { work_item }
          let_it_be(:sync_object) { epic }

          it_behaves_like 'deletes label events on both epic and epic work item'
        end
      end

      context 'with unified resource_state_events' do
        shared_examples 'deletes state events on both epic and epic work item' do
          it 'deletes the epic, epic work item and all notes' do
            epic_id = epic.id
            epic_work_item_id = epic.issue_id

            expect(ResourceStateEvent.where(epic_id: epic_id).count).to eq(1)
            expect(ResourceStateEvent.where(issue_id: epic_work_item_id).count).to eq(1)

            expect { subject.execute(issuable) }.to change { Epic.count }.by(-1).and(
              change { WorkItem.count }.by(-1)).and(change { ResourceStateEvent.count }.by(-2))

            expect(Epic.find_by_id(epic_id)).to be_nil
            expect(WorkItem.find_by_id(epic_work_item_id)).to be_nil
            expect(ResourceStateEvent.where(epic_id: epic_id).count).to eq(0)
            expect(ResourceStateEvent.where(issue_id: epic_work_item_id).count).to eq(0)
          end
        end

        context 'when deleting the epic' do
          let_it_be(:epic, freeze: false) { create(:epic, group: group) }
          let_it_be(:work_item) { epic.sync_object }
          let_it_be(:label1) { create(:group_label, group: group) }
          let_it_be(:label2, freeze: false) { create(:group_label, group: group) }
          let_it_be(:state_resource_event1) { create(:resource_state_event, epic: epic, state: :closed) }
          let_it_be(:state_resource_event2) { create(:resource_state_event, issue: work_item, state: :opened) }

          let_it_be(:issuable) { epic }
          let_it_be(:sync_object) { work_item }

          it_behaves_like 'deletes state events on both epic and epic work item'
        end

        context 'when deleting the epic work item' do
          let_it_be(:epic, freeze: false) { create(:epic, group: group) }
          let_it_be(:work_item) { epic.sync_object }
          let_it_be(:label1) { create(:group_label, group: group) }
          let_it_be(:label2, freeze: false) { create(:group_label, group: group) }
          let_it_be(:state_resource_event1) { create(:resource_state_event, epic: epic, state: :closed) }
          let_it_be(:state_resource_event2) { create(:resource_state_event, issue: work_item, state: :opened) }

          let_it_be(:issuable) { work_item }
          let_it_be(:sync_object) { epic }

          it_behaves_like 'deletes state events on both epic and epic work item'
        end
      end

      context 'with unified description_versions' do
        shared_examples 'deletes description versions on both epic and epic work item' do
          it 'deletes the epic, epic work item and all notes' do
            epic_id = epic.id
            epic_work_item_id = epic.issue_id

            expect(DescriptionVersion.where(epic_id: epic_id).count).to eq(1)
            expect(DescriptionVersion.where(issue_id: epic_work_item_id).count).to eq(1)

            expect { subject.execute(issuable) }.to change { Epic.count }.by(-1).and(
              change { WorkItem.count }.by(-1)).and(change { DescriptionVersion.count }.by(-2))

            expect(Epic.find_by_id(epic_id)).to be_nil
            expect(WorkItem.find_by_id(epic_work_item_id)).to be_nil
            expect(DescriptionVersion.where(epic_id: epic_id).count).to eq(0)
            expect(DescriptionVersion.where(issue_id: epic_work_item_id).count).to eq(0)
          end
        end

        context 'when deleting the epic' do
          let_it_be(:epic, freeze: false) { create(:epic, group: group) }
          let_it_be(:work_item) { epic.sync_object }
          let_it_be(:label1) { create(:group_label, group: group) }
          let_it_be(:label2, freeze: false) { create(:group_label, group: group) }
          let_it_be(:version1) { create(:description_version, epic: epic) }
          let_it_be(:version2) { create(:description_version, issue: work_item) }

          let_it_be(:issuable) { epic }
          let_it_be(:sync_object) { work_item }

          it_behaves_like 'deletes description versions on both epic and epic work item'
        end

        context 'when deleting the epic work item' do
          let_it_be(:epic, freeze: false) { create(:epic, group: group) }
          let_it_be(:work_item) { epic.sync_object }
          let_it_be(:label1) { create(:group_label, group: group) }
          let_it_be(:label2, freeze: false) { create(:group_label, group: group) }
          let_it_be(:version1) { create(:description_version, epic: epic) }
          let_it_be(:version2) { create(:description_version, issue: work_item) }

          let_it_be(:issuable) { work_item }
          let_it_be(:sync_object) { epic }

          it_behaves_like 'deletes description versions on both epic and epic work item'
        end
      end
    end

    context 'when destroying other issuable type' do
      let(:issuable) { create(:issue) }

      it 'does not track usage ping epic destroy event' do
        expect(Gitlab::UsageDataCounters::EpicActivityUniqueCounter).not_to receive(:track_epic_destroyed)

        subject.execute(issuable)
      end

      RSpec.shared_examples 'logs delete issuable audit event' do
        it 'logs audit event' do
          audit_context = {
            name: "delete_#{issuable.to_ability_name}",
            stream_only: true,
            author: user,
            scope: scope,
            target: issuable,
            message: "Removed #{issuable_name}(#{issuable.title} with IID: #{issuable.iid} and ID: #{issuable.id})",
            target_details: { title: issuable.title, iid: issuable.iid, id: issuable.id, type: issuable_name }
          }

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

          service.execute(issuable)
        end
      end

      context 'when issuable is an issue' do
        let(:issuable_name) { issuable.work_item_type.name }
        let(:scope) { issuable.project }

        it_behaves_like 'logs delete issuable audit event'
      end

      context 'when issuable is an epic' do
        let(:issuable) { create(:epic) }
        let(:issuable_name) { 'Epic' }
        let(:scope) { issuable.group }

        it_behaves_like 'logs delete issuable audit event'
      end

      context 'when issuable is a task' do
        let(:issuable) { create(:work_item, :task) }
        let(:issuable_name) { issuable.work_item_type.name }
        let(:scope) { issuable.project }

        it_behaves_like 'logs delete issuable audit event'
      end

      context 'when issuable is a merge_request' do
        let(:issuable) { create(:merge_request) }
        let(:issuable_name) { 'MergeRequest' }
        let(:scope) { issuable.project }

        it 'calls MergeRequestDestroyAuditor with correct arguments' do
          expect_next_instance_of(MergeRequests::MergeRequestDestroyAuditor, issuable, user) do |instance|
            expect(instance).to receive(:execute)
          end

          service.execute(issuable)
        end

        it 'calls MergeRequestBeforeDestroyAuditor with correct arguments' do
          expect_next_instance_of(MergeRequests::MergeRequestBeforeDestroyAuditor, issuable, user) do |instance|
            expect(instance).to receive(:execute)
          end

          service.execute(issuable)
        end
      end
    end
  end
end
