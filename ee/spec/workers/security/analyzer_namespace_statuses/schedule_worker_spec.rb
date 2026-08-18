# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerNamespaceStatuses::ScheduleWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }

  let_it_be(:group1) { create(:group) }
  let_it_be(:group2) { create(:group) }
  let_it_be(:group3) { create(:group) }
  let_it_be(:group4) { create(:group) }
  let_it_be(:group5) { create(:group) }
  let_it_be(:deleted_group) { create(:group, state: :deletion_in_progress) }
  let_it_be(:user_namespace) { create(:user_namespace) }
  let(:finder_service) { Security::AnalyzerNamespaceStatuses::FindNamespacesWithAnalyzerStatusesService }
  let(:adjustment_worker) { Security::AnalyzerNamespaceStatuses::AdjustmentWorker }

  before do
    allow(adjustment_worker).to receive(:perform_in)
    stub_const("Security::AnalyzerNamespaceStatuses::ScheduleWorker::BATCH_SIZE", 3)
  end

  describe "#perform" do
    context 'when deleted groups and user namespaces exist' do
      let(:passed_ids) { [] }

      before do
        allow(finder_service)
          .to receive(:execute) do |values|
          passed_ids.concat(values.map(&:first)) # take namespace_id
          []
        end
      end

      it 'does not pass deleted groups or user namespaces to FindNamespacesWithAnalyzerStatusesService' do
        worker.perform

        expect(passed_ids).not_to include(deleted_group.id)
        expect(passed_ids).not_to include(user_namespace.id)
        expect(passed_ids).to include(group1.id, group2.id, group3.id, group4.id, group5.id)
      end
    end

    context 'when no namespaces have analyzer statuses' do
      before do
        allow(finder_service)
          .to receive(:execute).and_return([])
      end

      it 'does not schedule an AdjustmentWorker' do
        worker.perform

        expect(finder_service)
          .to have_received(:execute).at_least(:once)
        expect(adjustment_worker)
          .not_to have_received(:perform_in)
      end
    end

    context 'when some namespaces have vulnerabilities but fewer than batch size' do
      before do
        allow(finder_service)
          .to receive(:execute).and_return([group1.id, group3.id], [])
      end

      it 'schedules an AdjustmentWorker with all vulnerable namespace IDs' do
        worker.perform

        expect(finder_service)
          .to have_received(:execute).at_least(:once)
        expect(adjustment_worker)
          .to have_received(:perform_in).with(0, [group1.id, group3.id])
      end
    end

    context 'when number of vulnerable namespaces equals batch size' do
      before do
        allow(finder_service)
          .to receive(:execute).and_return([group1.id, group2.id, group3.id], [])
      end

      it 'schedules an AdjustmentWorker with all vulnerable namespace ids in one batch' do
        worker.perform

        expect(finder_service)
          .to have_received(:execute).at_least(:once)
        expect(adjustment_worker)
          .to have_received(:perform_in).with(0, [group1.id, group2.id, group3.id])
      end
    end

    context 'when processing multiple batches' do
      before do
        stub_const("Security::AnalyzerNamespaceStatuses::ScheduleWorker::BATCH_SIZE", 2)

        allow(finder_service)
          .to receive(:execute).and_return([group1.id], [group3.id, group4.id], [])
      end

      it 'accumulates vulnerable ids across batches and schedules correctly' do
        worker.perform

        expect(finder_service)
          .to have_received(:execute).exactly(3).times
        expect(adjustment_worker)
          .to have_received(:perform_in).with(0, [group1.id, group3.id]).once
        expect(adjustment_worker)
          .to have_received(:perform_in).with(described_class::DELAY_INTERVAL, [group4.id]).once
      end
    end
  end
end
