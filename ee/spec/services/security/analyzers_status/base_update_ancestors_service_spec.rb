# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::BaseUpdateAncestorsService, feature_category: :security_asset_inventories do
  let(:service) { described_class.new(:vulnerable) }
  let_it_be(:group) { create(:group) }
  let(:analyzer_statuses) do
    [instance_double(Security::AnalyzerNamespaceStatus, analyzer_type: 'sast', success: 10, failure: 2)]
  end

  describe '.execute' do
    it 'instantiates a new service object and calls execute' do
      expect_next_instance_of(described_class, :vulnerable) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(:vulnerable)
    end
  end

  describe '#execute' do
    context 'when there are no analyzer statuses' do
      before do
        allow(service).to receive(:analyzer_statuses).and_return(nil)
      end

      it 'does nothing' do
        expect(service).not_to receive(:reduce_from_old_ancestors)
        service.execute
      end
    end

    context 'when analyzer statuses are present' do
      before do
        allow(service).to receive(:analyzer_statuses).and_return(analyzer_statuses)
        allow(service).to receive(:reduce_from_old_ancestors)
        allow(service).to receive(:add_to_new_ancestors)
        allow(Security::AnalyzerNamespaceStatus).to receive(:transaction).and_yield
      end

      it 'uses a transaction' do
        expect(Security::AnalyzerNamespaceStatus).to receive(:transaction)
        service.execute
      end

      it 'calls reduce_from_old_ancestors and add_to_new_ancestors' do
        expect(service).to receive(:reduce_from_old_ancestors)
        expect(service).to receive(:add_to_new_ancestors)

        service.execute
      end
    end
  end

  describe '#reduce_from_old_ancestors' do
    before do
      allow(service).to receive(:diffs).with(nil, -1).and_return(['reduced_diffs'])
    end

    it 'calls AncestorsUpdateService with the reduced diffs' do
      expect(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService).to receive(:execute).with(['reduced_diffs'])
      service.send(:reduce_from_old_ancestors)
    end
  end

  describe '#add_to_new_ancestors' do
    let(:namespace) { instance_double(Group, traversal_ids: [1, 4, 3]) }

    before do
      allow(service).to receive(:namespace).and_return(namespace)
      allow(service).to receive(:diffs).with(namespace.traversal_ids).and_return(['increased_diffs'])
    end

    it 'calls AncestorsUpdateService with the increased diffs' do
      expect(Security::AnalyzerNamespaceStatuses::AncestorsUpdateService).to receive(:execute).with(['increased_diffs'])
      service.send(:add_to_new_ancestors)
    end
  end

  describe '#vulnerable_namespace' do
    it 'requires a subclass overrides it' do
      expect { service.send(:namespace) }.to raise_error(NotImplementedError)
    end
  end

  describe '#diffs' do
    it 'requires a subclass overrides it' do
      expect { service.send(:diffs, [1, 2, 3]) }.to raise_error(NotImplementedError)
    end
  end

  describe '#analyzer_statuses' do
    it 'requires a subclass overrides it' do
      expect { service.send(:analyzer_statuses) }.to raise_error(NotImplementedError)
    end
  end
end
