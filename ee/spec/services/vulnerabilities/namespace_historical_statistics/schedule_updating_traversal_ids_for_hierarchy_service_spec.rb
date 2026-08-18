# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceHistoricalStatistics::ScheduleUpdatingTraversalIdsForHierarchyService, feature_category: :vulnerability_management do
  describe '.execute' do
    it 'instantiates a new service object and calls execute' do
      expect_next_instance_of(described_class, :group) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(:group)
    end
  end

  describe '#execute' do
    let_it_be(:parent_group) { create(:group) }
    let_it_be(:child_group_1) { create(:group, parent: parent_group) }
    let_it_be(:child_group_2) { create(:group, parent: parent_group) }

    let(:service_object) { described_class.new(parent_group) }
    let(:worker_class) { Vulnerabilities::NamespaceHistoricalStatistics::UpdateTraversalIdsWorker }

    subject(:schedule_update) { service_object.execute }

    before do
      create(:vulnerability_namespace_historical_statistic, namespace: parent_group)
      create(:vulnerability_namespace_historical_statistic, namespace: child_group_2)

      allow(worker_class).to receive(:perform_bulk)
    end

    it 'schedules updating the traversal_ids only for relevant groups' do
      schedule_update

      expect(worker_class).to have_received(:perform_bulk).with([[parent_group.id], [child_group_2.id]])
    end

    describe 'iterating over child groups in batches' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)
      end

      it 'schedules the worker twice' do
        schedule_update

        expect(worker_class).to have_received(:perform_bulk).with([[parent_group.id]])
        expect(worker_class).to have_received(:perform_bulk).with([[child_group_2.id]])
      end
    end
  end
end
