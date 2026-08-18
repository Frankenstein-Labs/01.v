# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuable::RelatedLinksCreateWorker, feature_category: :portfolio_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:issuable) { create(:work_item, :task, project: project) }
  let_it_be(:item1) { create(:work_item, :task, project: project) }
  let_it_be(:item2) { create(:work_item, :task, project: project) }
  let_it_be(:user) { create(:user, reporter_of: project) }

  let(:params) do
    {
      issuable_class: issuable.class.name,
      issuable_id: issuable.id,
      user_id: user.id
    }
  end

  subject(:worker) { described_class.new.perform(params) }

  before_all do
    # Ensure support bot user is created so creation doesn't count towards query limit
    # and we don't try to obtain an exclusive lease within a transaction.
    # See https://gitlab.com/gitlab-org/gitlab/-/issues/509629
    create(:support_bot)
  end

  describe '#perform' do
    context 'when items are marked as blocked' do
      let(:blocked1) { item1 }
      let(:blocked2) { item2 }

      before do
        blocked_link1 = create(:work_item_link, source: issuable, target: blocked1, link_type: 'blocks')
        blocked_link2 = create(:work_item_link, source: issuable, target: blocked2, link_type: 'blocks')

        params.merge!(link_ids: [blocked_link1.id, blocked_link2.id], link_type: 'blocks')
      end

      it 'calls correct methods on SystemNoteService' do
        expect(SystemNoteService).to receive(:block_issuable).with(issuable, [blocked1, blocked2], user)
        expect(SystemNoteService).to receive(:blocked_by_issuable).with(blocked1, issuable, user)
        expect(SystemNoteService).to receive(:blocked_by_issuable).with(blocked2, issuable, user)

        worker
      end

      it 'creates correct notes' do
        worker

        expect(issuable.notes.last.note)
          .to eq("marked this item as blocking #{blocked1.to_reference} and #{blocked2.to_reference}")
        expect(blocked1.notes.last.note).to eq("marked this item as blocked by #{issuable.to_reference}")
        expect(blocked2.notes.last.note).to eq("marked this item as blocked by #{issuable.to_reference}")
      end
    end

    context 'when items are marked as blocking' do
      let(:blocking1) { item1 }
      let(:blocking2) { item2 }

      before do
        blocking_link1 = create(:work_item_link, source: blocking1, target: issuable, link_type: 'blocks')
        blocking_link2 = create(:work_item_link, source: blocking2, target: issuable, link_type: 'blocks')

        params.merge!(link_ids: [blocking_link1.id, blocking_link2.id], link_type: 'is_blocked_by')
      end

      it 'calls correct methods on SystemNoteService' do
        expect(SystemNoteService).to receive(:blocked_by_issuable).with(issuable, [blocking1, blocking2], user)
        expect(SystemNoteService).to receive(:block_issuable).with(blocking1, issuable, user)
        expect(SystemNoteService).to receive(:block_issuable).with(blocking2, issuable, user)

        worker
      end

      it 'creates correct notes' do
        worker

        expect(issuable.notes.last.note)
          .to eq("marked this item as blocked by #{blocking1.to_reference} and #{blocking2.to_reference}")
        expect(blocking1.notes.last.note).to eq("marked this item as blocking #{issuable.to_reference}")
        expect(blocking2.notes.last.note).to eq("marked this item as blocking #{issuable.to_reference}")
      end
    end

    context 'with tracking work item events' do
      let_it_be(:blocking_target) { create(:work_item, :task, project: project) }
      let_it_be(:blocked_source) { create(:work_item, :task, project: project) }
      let_it_be(:blocking_link) do
        create(:work_item_link, source: issuable, target: blocking_target, link_type: 'blocks')
      end

      let_it_be(:blocked_link) do
        create(:work_item_link, source: blocked_source, target: issuable, link_type: 'blocks')
      end

      let(:work_item) { issuable }
      let(:current_user) { user }

      def execute_service
        described_class.new.perform(params)
      end

      context 'with blocks link_type' do
        before do
          params.merge!(link_ids: [blocking_link.id], link_type: 'blocks')
        end

        it_behaves_like 'tracks work item event', :work_item, :current_user,
          Gitlab::WorkItems::Instrumentation::EventActions::BLOCKING_ITEM_ADD, :execute_service
      end

      context 'with blocked_by link type' do
        before do
          params.merge!(link_ids: [blocked_link.id], link_type: 'blocks')
        end

        it_behaves_like 'tracks work item event', :work_item, :current_user,
          Gitlab::WorkItems::Instrumentation::EventActions::BLOCKED_BY_ITEM_ADD, :execute_service
      end
    end
  end
end
