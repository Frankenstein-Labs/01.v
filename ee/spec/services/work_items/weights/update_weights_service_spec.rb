# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Weights::UpdateWeightsService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:parent) { create(:work_item, :issue, project: project) }
  let_it_be(:child) { create(:work_item, :task, project: project, weight: 5) }
  let_it_be(:child2) { create(:work_item, :task, project: project, weight: 3) }

  let_it_be(:parent_link) { create(:parent_link, work_item: child, work_item_parent: parent) }
  let_it_be(:parent_link2) { create(:parent_link, work_item: child2, work_item_parent: parent) }

  describe '#execute' do
    subject(:service) { described_class.new(work_items) }

    context 'when updating a single work item' do
      let(:work_items) { child }

      it 'updates weights for all ancestors' do
        expect(WorkItems::WeightsSource).to receive(:upsert_rolled_up_weights_for).with(child).ordered
        expect(WorkItems::WeightsSource).to receive(:upsert_rolled_up_weights_for).with(parent).ordered

        service.execute
      end
    end

    context 'when updating multiple work items' do
      let(:work_items) { [child, child2] }

      it 'updates weights for all work items and their ancestors' do
        expect(WorkItems::WeightsSource).to receive(:upsert_rolled_up_weights_for).with(child).ordered
        expect(WorkItems::WeightsSource).to receive(:upsert_rolled_up_weights_for).with(parent).ordered
        expect(WorkItems::WeightsSource).to receive(:upsert_rolled_up_weights_for).with(child2).ordered
        expect(WorkItems::WeightsSource).to receive(:upsert_rolled_up_weights_for).with(parent).ordered

        service.execute
      end
    end

    context 'when work item has no ancestors' do
      let(:work_items) { parent }

      it 'only updates weights for the work item itself' do
        expect(WorkItems::WeightsSource).to receive(:upsert_rolled_up_weights_for).with(parent)

        service.execute
      end
    end

    context 'when work item has ancestors' do
      let(:work_items) { child }

      it 'processes the ancestor weight update loop' do
        # This test specifically covers the uncovered line 25 in the ancestor loop
        ancestors = [parent]
        allow(child).to receive(:ancestors).and_return(ancestors)

        expect(WorkItems::WeightsSource).to receive(:upsert_rolled_up_weights_for).with(child).ordered
        ancestors.each do |ancestor|
          expect(WorkItems::WeightsSource).to receive(:upsert_rolled_up_weights_for).with(ancestor).ordered
        end

        service.execute
      end
    end

    context 'when initialized with array of work items' do
      let(:work_items) { [child] }

      it 'processes all work items in the array' do
        expect(WorkItems::WeightsSource).to receive(:upsert_rolled_up_weights_for).with(child).ordered
        expect(WorkItems::WeightsSource).to receive(:upsert_rolled_up_weights_for).with(parent).ordered

        service.execute
      end
    end
  end
end
