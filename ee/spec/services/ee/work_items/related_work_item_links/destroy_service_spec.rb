# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::RelatedWorkItemLinks::DestroyService, feature_category: :portfolio_management do
  describe '#execute' do
    let_it_be(:project) { create(:project_empty_repo, :private) }
    let_it_be(:user) { create(:user) }
    let_it_be(:source) { create(:work_item, project: project) }
    let_it_be(:linked_item) { create(:work_item, project: project) }

    let_it_be(:link) { create(:work_item_link, source: source, target: linked_item) }

    let(:extra_params) { {} }
    let(:ids_to_remove) { [linked_item.id] }

    subject(:destroy_links) do
      described_class.new(source, user, { item_ids: ids_to_remove, extra_params: extra_params }).execute
    end

    before_all do
      project.add_guest(user)
    end

    context 'when there is an epic for the work item' do
      let_it_be(:group) { create(:group) }
      let_it_be(:epic_a) { create(:epic, :with_synced_work_item, group: group) }
      let_it_be(:epic_b) { create(:epic, :with_synced_work_item, group: group) }
      let_it_be(:source) { epic_a.work_item }
      let_it_be(:target) { epic_b.work_item }
      let_it_be(:link) { create(:work_item_link, source: source, target: target) }
      let_it_be_with_reload(:related_epic_link) do
        create(:related_epic_link, source: epic_a, target: epic_b, related_work_item_link: link)
      end

      let_it_be(:ids_to_remove) { [target.id] }

      before_all do
        group.add_guest(user)
      end

      before do
        stub_licensed_features(epics: true, related_epics: true)
      end

      it 'creates system notes' do
        expect(SystemNoteService).to receive(:unrelate_issuable).with(source, target, user)
        expect(SystemNoteService).to receive(:unrelate_issuable).with(target, source, user)

        destroy_links
      end

      it 'destroys both links' do
        expect { destroy_links }.to change { WorkItems::RelatedWorkItemLink.count }.by(-1)
          .and change { Epic::RelatedEpicLink.count }.by(-1)

        expect(epic_a.related_epics(user)).to be_empty
        expect(source.linked_work_items(authorize: false)).to be_empty
      end

      it 'calls this service once' do
        allow(described_class).to receive(:new).and_call_original
        expect(described_class).to receive(:new).once

        destroy_links
      end

      it 'creates notes only for work item', :sidekiq_inline do
        expect { destroy_links }.to change { Epic::RelatedEpicLink.count }.by(-1)
          .and change { WorkItems::RelatedWorkItemLink.count }.by(-1)
          .and change { source.notes.count }.by(1)
          .and change { target.notes.count }.by(1)
          .and not_change { epic_a.own_notes.count }
          .and not_change { epic_b.own_notes.count }
      end
    end

    context 'with tracking work item events' do
      let_it_be(:blocking_target) { create(:work_item, project: project) }
      let_it_be(:blocked_source) { create(:work_item, project: project) }
      let_it_be(:blocking_link) do
        create(:work_item_link, source: source, target: blocking_target, link_type: 'blocks')
      end

      let_it_be(:blocked_link) { create(:work_item_link, source: blocked_source, target: source, link_type: 'blocks') }

      let(:work_item) { source }
      let(:current_user) { user }

      def execute_service
        described_class.new(source, user, { item_ids: ids_to_remove }).execute
      end
      context 'with blocks link_type' do
        let(:ids_to_remove) { [blocking_target.id] }

        it_behaves_like 'tracks work item event', :work_item, :current_user,
          Gitlab::WorkItems::Instrumentation::EventActions::BLOCKING_ITEM_REMOVE,
          :execute_service
      end

      context 'with blocked_by link type' do
        let(:ids_to_remove) { [blocked_source.id] }

        it_behaves_like 'tracks work item event', :work_item, :current_user,
          Gitlab::WorkItems::Instrumentation::EventActions::BLOCKED_BY_ITEM_REMOVE,
          :execute_service
      end
    end
  end
end
