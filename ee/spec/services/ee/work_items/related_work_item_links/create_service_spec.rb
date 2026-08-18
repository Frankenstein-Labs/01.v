# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::RelatedWorkItemLinks::CreateService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:work_item) { create(:work_item, project: project) }
    let_it_be(:reporter) { create(:user, reporter_of: project) }
    let_it_be(:user) { reporter }
    let_it_be(:work_item_a) { create(:work_item, project: project) }
    let_it_be(:project2) { create(:project, namespace: project.namespace, reporters: reporter) }
    let_it_be(:another_work_item) { create(:work_item, project: project2) }
    let_it_be(:group) { create(:group) }

    let(:link_class) { ::WorkItems::RelatedWorkItemLink }
    let(:params) { { target_issuable: [work_item_a, another_work_item] } }

    subject(:link_items) { described_class.new(work_item, user, params).execute }

    shared_examples 'successful response' do |link_type:|
      before do
        params[:link_type] = link_type
      end

      it 'creates relationships' do
        expect { link_items }.to change { link_class.count }.by(2)
      end

      it 'returns success status and created links', :aggregate_failures do
        expect(link_items.keys).to match_array([:status, :created_references, :message])
        expect(link_items[:status]).to eq(:success)
        expect(link_items[:created_references]).not_to be_empty
        expect(link_items[:message]).to eq("Successfully linked ID(s): #{work_item_a.id} and #{another_work_item.id}.")
      end
    end

    shared_examples 'error response' do |link_type:|
      before do
        params[:link_type] = link_type
      end

      it 'returns error' do
        is_expected.to eq(
          message: 'Blocked work items are not available for the current subscription tier',
          status: :error,
          http_status: 403
        )
      end

      it 'no relationship is created' do
        expect { link_items }.not_to change { link_class.count }
      end
    end

    context 'when licensed feature `blocked_work_items` is available' do
      before do
        stub_licensed_features(blocked_work_items: true)
      end

      it_behaves_like 'issuable link creation with blocking link_type' do
        let(:async_notes) { true }
        let(:issuable_link_class) { link_class }
        let(:issuable) { work_item }
        let(:issuable2) { work_item_a }
        let(:issuable3) { another_work_item }
      end

      it_behaves_like 'successful response', link_type: 'blocks'
      it_behaves_like 'successful response', link_type: 'is_blocked_by'
    end

    context 'when linking group level work items' do
      let_it_be(:work_item) { create(:work_item, namespace: group) }
      let_it_be(:another_work_item) { create(:work_item, namespace: group) }

      before_all do
        group.add_guest(user)
      end

      before do
        stub_licensed_features(epics: true, related_epics: true, blocked_work_items: true)
      end

      shared_examples 'successfully links work items' do
        it 'creates relationships and notes' do
          expect { link_items }.to change { link_class.count }.by(1)

          expect(link_items.keys).to match_array([:status, :created_references, :message])
          expect(link_items[:status]).to eq(:success)
          expect(link_items[:created_references]).not_to be_empty
          expect(link_items[:message]).to eq("Successfully linked ID(s): #{another_work_item.id}.")
        end
      end

      context 'when using issuable_references param' do
        let_it_be(:params) do
          { issuable_references: [another_work_item.to_reference(full: true)] }
        end

        it_behaves_like 'successfully links work items'
      end

      context 'when using target_issuable param' do
        let_it_be(:params) do
          { target_issuable: [another_work_item] }
        end

        it_behaves_like 'successfully links work items'
      end
    end

    context 'for epic work items' do
      let_it_be(:epic) { create(:epic, group: group) }
      let_it_be(:epic_a) { create(:epic, group: group) }
      let_it_be(:epic_b) { create(:epic, group: group) }
      let_it_be_with_refind(:work_item) { epic.work_item }
      let_it_be(:work_item_a) { epic_a.work_item }
      let_it_be(:another_work_item) { epic_b.work_item }

      let(:params) do
        { target_issuable: [work_item_a, another_work_item], link_type: 'blocks' }
      end

      before_all do
        group.add_guest(user)
      end

      before do
        stub_licensed_features(epics: true, related_epics: true, blocked_work_items: true)
      end

      it_behaves_like 'successful response', link_type: 'blocks'
      it_behaves_like 'successful response', link_type: 'is_blocked_by'

      context 'when using issuable_references param with legacy epic reference' do
        let(:params) do
          {
            issuable_references: [
              work_item_a.synced_epic.to_reference(full: true), another_work_item.synced_epic.to_reference(full: true)
            ]
          }
        end

        it 'successfully creates the records' do
          expect { link_items }.to change { Epic::RelatedEpicLink.count }.and change { IssueLink.count }
        end
      end

      context 'when one work item is not an epic' do
        let_it_be(:issue_work_item) { create(:work_item, :issue, namespace: group) }

        shared_examples 'successful execution' do
          it 'does not try to sync' do
            expect(::Epic::RelatedEpicLink).not_to receive(:find_or_initialize_from_work_item_link)

            expect { link_items }.to not_change { Epic::RelatedEpicLink.count }
              .and change { link_class.count }.by(1)
          end
        end

        context 'when target is not a work item' do
          let(:params) do
            { target_issuable: [issue_work_item], link_type: 'blocks' }
          end

          it_behaves_like 'successful execution'
        end

        context 'when source is not a work item' do
          let(:params) do
            { target_issuable: [issue_work_item], link_type: 'is_blocked_by' }
          end

          it_behaves_like 'successful execution'
        end
      end

      it 'syncs with a RelatedEpicLink record' do
        expect { link_items }.to change { Epic::RelatedEpicLink.count }.by(2)

        synced_links = Epic::RelatedEpicLink.where(source_id: epic.id)
        expect(synced_links.map(&:link_type).uniq).to eq(['blocks'])
        expect(synced_links.map(&:target)).to match_array([epic_a, epic_b])
        expect(synced_links.map(&:issue_link_id)).to match_array(link_class.pluck(:id))
      end

      context 'when there is only a partial success' do
        # Using work_item as target_issuable will let the link creation fail as it's a reference to itself.
        let(:params) do
          {
            target_issuable: [work_item, another_work_item],
            link_type: 'blocks'
          }
        end

        it 'does not create any links or system notes' do
          expect(Issuable::RelatedLinksCreateWorker).not_to receive(:perform_async)
          expect { link_items }.to not_change { Epic::RelatedEpicLink.count }
            .and not_change { link_class.count }
            .and not_change { Note.count }

          expect(link_items[:status]).to eq(:error)
        end
      end

      it 'calls this service once' do
        allow(described_class).to receive(:new).and_call_original
        expect(described_class).to receive(:new).once

        link_items
      end

      it 'creates notes only for work item', :sidekiq_inline do
        expect { link_items }.to change { Epic::RelatedEpicLink.count }.by(2)
          .and change { link_class.count }.by(2)
          .and change { work_item.notes.count }.by(1)
          .and not_change { epic_a.own_notes.count }
          .and not_change { epic_b.own_notes.count }

        expect(work_item.notes.last.note).to eq(
          "marked this item as blocking #{work_item_a.to_reference} and #{another_work_item.to_reference}"
        )
      end

      context 'when work item is not of epic type' do
        let_it_be(:work_item) { create(:work_item, :group_level, namespace: group) }

        it 'does not sync with a RelatedEpicLink record' do
          expect { link_items }.to not_change { Epic::RelatedEpicLink.count }
            .and change { link_class.count }.by(2)
        end
      end

      context 'when work item does not have a synced epic' do
        let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }

        it 'does not sync with a RelatedEpicLink record' do
          expect { link_items }.to not_change { Epic::RelatedEpicLink.count }
            .and change { link_class.count }.by(2)
        end
      end

      context 'when a target work item does not have synced epic' do
        let_it_be(:work_item_a) { create(:work_item, :epic, namespace: group) }

        it 'only creates related epic links for targets with synced epics' do
          expect { link_items }.to change { Epic::RelatedEpicLink.count }.by(1)

          synced_links = Epic::RelatedEpicLink.where(source_id: epic.id)
          expect(synced_links.map(&:link_type).uniq).to eq(['blocks'])
          expect(synced_links.map(&:target)).to match_array([epic_b])
        end
      end

      context 'when the target work item does not a have synced epic' do
        let_it_be(:task) { create(:work_item, :task, project: project) }

        let(:params) do
          { target_issuable: [task], link_type: 'blocks' }
        end

        it 'does not create related epic links for targets' do
          expect { link_items }.to change { ::WorkItems::RelatedWorkItemLink.count }.by(1)
                               .and not_change { Epic::RelatedEpicLink.count }
        end
      end

      context 'when something goes wrong creating work item link' do
        before do
          allow_next_instance_of(link_class) do |instance|
            errors = ActiveModel::Errors.new(instance).tap { |e| e.add(:source, 'error message') }
            allow(instance).to receive_messages(save: false, errors: errors)
          end
        end

        it 'does not create a related work item link or epic link' do
          error_message =
            "#{work_item_a.to_reference} cannot be added: error message. " \
              "#{another_work_item.to_reference} cannot be added: error message"

          expect { link_items }.to not_change { Epic::RelatedEpicLink.count }
            .and not_change { link_class.count }

          expect(link_items).to eq(message: error_message, status: :error, http_status: 422)
        end
      end

      context 'when something goes wrong creating related epic link' do
        before do
          allow_next_instance_of(Epic::RelatedEpicLink) do |instance|
            errors = ActiveModel::Errors.new(instance).tap { |e| e.add(:base, 'Some error') }
            allow(instance).to receive_messages(save: false, errors: errors)
          end
        end

        it 'does not create a related work item link or epic link' do
          expect(Gitlab::EpicWorkItemSync::Logger).to receive(:error)
            .with({
              message: 'Not able to create related epic links',
              error_message: 'Some error',
              group_id: group.id,
              work_item_id: work_item.id
            })

          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(WorkItems::SyncAsEpic::SyncAsEpicError),
            { work_item_id: work_item.id }
          )

          expect { link_items }.to not_change { Epic::RelatedEpicLink.count }
            .and not_change { link_class.count }
        end

        it 'returns an error' do
          expect(link_items)
            .to eq({ status: :error, message: "Some error", http_status: 422 })
        end
      end
    end

    context 'when licensed feature `blocked_work_items` is not available' do
      before do
        stub_licensed_features(blocked_work_items: false)
      end

      it_behaves_like 'error response', link_type: 'blocks'
      it_behaves_like 'error response', link_type: 'is_blocked_by'
    end
  end
end
