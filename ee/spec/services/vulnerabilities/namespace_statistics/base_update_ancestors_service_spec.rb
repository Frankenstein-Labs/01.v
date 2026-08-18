# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::BaseUpdateAncestorsService, feature_category: :security_asset_inventories do
  let(:service) { described_class.new(:vulnerable) }
  let_it_be(:group) { create(:group) }
  let(:statistics) do
    instance_double(Vulnerabilities::NamespaceStatistic,
      total: 10, critical: 4, high: 3, medium: 2, low: 1, info: 0, unknown: 0)
  end

  describe '#execute' do
    context 'when traversal_ids have not changed' do
      before do
        allow(service).to receive_messages(previous_traversal_ids: [1, 2, 3],
          vulnerable_namespace: instance_double(Group, traversal_ids: [1, 2, 3]))
      end

      it 'does nothing' do
        expect(service).not_to receive(:reduce_from_old_ancestors)
        service.execute
      end
    end

    context 'when previous_traversal_ids is nil' do
      before do
        allow(service).to receive(:previous_traversal_ids).and_return(nil)
      end

      it 'does nothing' do
        expect(service).not_to receive(:reduce_from_old_ancestors)
        service.execute
      end
    end

    context 'when traversal_ids have changed' do
      before do
        allow(service).to receive_messages(previous_traversal_ids: [1, 2, 3],
          vulnerable_namespace: instance_double(Group, traversal_ids: [1, 4, 3]))
        allow(service).to receive(:reduce_from_old_ancestors)
        allow(service).to receive(:add_to_new_ancestors)
        allow(Vulnerabilities::NamespaceStatistic).to receive(:transaction).and_yield
      end

      it 'uses a transaction' do
        expect(Vulnerabilities::NamespaceStatistic).to receive(:transaction)
        service.execute
      end

      it 'calls reduce_from_old_ancestors and add_to_new_ancestors' do
        expect(service).to receive(:reduce_from_old_ancestors)
        expect(service).to receive(:add_to_new_ancestors)

        service.execute
      end
    end
  end

  describe '#diff' do
    let(:namespace) { instance_double(Group, id: 42) }
    let(:traversal_ids) { [1, 2, 3] }

    before do
      allow(service).to receive(:vulnerable_namespace).and_return(namespace)
    end

    it 'returns correct diff format with default coefficient' do
      result = service.send(:diff, statistics, traversal_ids)

      expect(result).to eq({
        "namespace_id" => 42,
        "traversal_ids" => "{1,2,3}",
        "total" => 10,
        "critical" => 4,
        "high" => 3,
        "medium" => 2,
        "low" => 1,
        "info" => 0,
        "unknown" => 0
      })
    end

    it 'returns diff with negated statistics when coefficient is -1' do
      result = service.send(:diff, statistics, traversal_ids, -1)

      expect(result).to eq({
        "namespace_id" => 42,
        "traversal_ids" => "{1,2,3}",
        "total" => -10,
        "critical" => -4,
        "high" => -3,
        "medium" => -2,
        "low" => -1,
        "info" => 0,
        "unknown" => 0
      })
    end
  end

  describe '#reduce_from_old_ancestors' do
    let(:previous_ids) { [1, 2, 3] }

    before do
      allow(service).to receive_messages(vulnerable_statistics: statistics, previous_traversal_ids: previous_ids)
      allow(service).to receive(:diff).with(statistics, previous_ids, -1).and_return('reduced_diff')
    end

    it 'calls UpdateService with the reduced diff' do
      expect(Vulnerabilities::NamespaceStatistics::UpdateService).to receive(:execute).with(['reduced_diff'])
      service.send(:reduce_from_old_ancestors)
    end
  end

  describe '#add_to_new_ancestors' do
    let(:namespace) { instance_double(Group, id: 42, traversal_ids: [1, 4, 3]) }

    before do
      allow(service).to receive_messages(vulnerable_statistics: statistics, vulnerable_namespace: namespace)
      allow(service).to receive(:diff).with(statistics, namespace.traversal_ids).and_return('increased_diff')
    end

    it 'calls UpdateService with the increased diff' do
      expect(Vulnerabilities::NamespaceStatistics::UpdateService).to receive(:execute).with(['increased_diff'])
      service.send(:add_to_new_ancestors)
    end
  end

  describe '#vulnerable_namespace' do
    it 'requires a subclass overrides it' do
      expect { service.send(:vulnerable_namespace) }.to raise_error(NotImplementedError)
    end
  end

  describe '#vulnerable_statistics' do
    it 'requires a subclass overrides it' do
      expect { service.send(:vulnerable_statistics) }.to raise_error(NotImplementedError)
    end
  end
end
